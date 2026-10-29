#!/usr/bin/env python3
"""Writes the Finder .DS_Store for the StandUp Pal disk image window: big icons,
the app on the left, an Applications shortcut on the right, the help note below,
and no toolbar or sidebar. Finder only reads this file (the image is read-only).

Usage: dmg-layout.py <path/to/.DS_Store> <app name> <help file name>

Format reference: Mac::Finder::DSStore "DSStoreFormat" (Wim Lewis, Mark Mentovai).
"""
import plistlib
import struct
import sys

WINDOW = (200, 120, 640, 440)  # x, y, width, height
ICON_SIZE = 100


def record(name, code, kind, value):
    data = struct.pack(">I", len(name)) + name.encode("utf-16-be") + code + kind
    if kind == b"long":
        data += struct.pack(">I", value)
    elif kind == b"type":
        data += value
    elif kind == b"blob":
        data += struct.pack(">I", len(value)) + value
    else:
        raise ValueError(kind)
    return data


def icon_location(x, y):
    return struct.pack(">II", x, y) + b"\xff" * 6 + b"\x00" * 2


def records(app, help_file):
    x, y, w, h = WINDOW
    window = plistlib.dumps({
        "ContainerShowSidebar": False, "ShowPathbar": False, "ShowSidebar": False, "ShowStatusBar": False,
        "ShowTabView": False, "ShowToolbar": False, "SidebarWidth": 0,
        "WindowBounds": "{{%d, %d}, {%d, %d}}" % (x, y, w, h),
    }, fmt=plistlib.FMT_BINARY)
    icons = plistlib.dumps({
        "arrangeBy": "none", "backgroundType": 0, "backgroundColorRed": 1.0, "backgroundColorGreen": 1.0,
        "backgroundColorBlue": 1.0, "gridOffsetX": 0.0, "gridOffsetY": 0.0, "gridSpacing": 100.0,
        "iconSize": float(ICON_SIZE), "labelOnBottom": True, "showIconPreview": True, "showItemInfo": False,
        "textSize": 13.0, "viewOptionsVersion": 1,
    }, fmt=plistlib.FMT_BINARY)
    entries = [
        (".", b"bwsp", b"blob", window),
        (".", b"icvp", b"blob", icons),
        (".", b"vSrn", b"long", 1),
        (".", b"vstl", b"type", b"icnv"),
        (app, b"Iloc", b"blob", icon_location(165, 165)),
        ("Applications", b"Iloc", b"blob", icon_location(475, 165)),
        (help_file, b"Iloc", b"blob", icon_location(320, 305)),
    ]
    # Finder expects records sorted by name (case-insensitively), then by code.
    entries.sort(key=lambda e: (e[0].lower(), e[1]))
    return [record(*e) for e in entries]


def free_lists(used, offset=0, size=1 << 31, lists=None):
    """Buddy-allocator free lists for everything outside the used blocks."""
    if lists is None:
        lists = [[] for _ in range(32)]
    end = offset + size
    if not any(start < end and offset < stop for start, stop in used):
        lists[size.bit_length() - 1].append(offset)
    elif size > 32:
        half = size // 2
        free_lists(used, offset, half, lists)
        free_lists(used, offset + half, half, lists)
    return lists


def ds_store(app, help_file):
    entries = records(app, help_file)
    node = struct.pack(">II", 0, len(entries)) + b"".join(entries)
    assert len(node) <= 0x1000, "layout records no longer fit one B-tree page"

    # Offsets are relative to byte 4 of the file; each block address carries log2(size).
    root_at, root_size = 0x800, 0x800
    master_at, master_size = 0x20, 0x20
    node_at, node_size = 0x1000, 0x1000
    master = struct.pack(">IIIII", 2, 0, len(entries), 1, 0x1000)

    addresses = [root_at | 11, master_at | 5, node_at | 12]
    root = struct.pack(">II", len(addresses), 0)
    root += struct.pack(">256I", *(addresses + [0] * (256 - len(addresses))))
    root += struct.pack(">I", 1) + bytes([4]) + b"DSDB" + struct.pack(">I", 1)
    used = [(0, 0x20), (master_at, master_at + master_size), (root_at, root_at + root_size), (node_at, node_at + node_size)]
    for offsets in free_lists(used):
        root += struct.pack(">I", len(offsets)) + b"".join(struct.pack(">I", o) for o in offsets)
    assert len(root) <= root_size

    data = bytearray(4 + node_at + node_size)
    data[0:4] = struct.pack(">I", 1)
    data[4:36] = b"Bud1" + struct.pack(">III", root_at, root_size, root_at) + b"\x00" * 16
    for at, block in ((root_at, root), (master_at, master), (node_at, node)):
        data[4 + at:4 + at + len(block)] = block
    return bytes(data)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    with open(sys.argv[1], "wb") as out:
        out.write(ds_store(sys.argv[2], sys.argv[3]))
