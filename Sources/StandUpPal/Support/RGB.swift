import AppKit
import SwiftUI

/// A tiny sRGB colour value we can persist as hex and shade for the pet.
struct RGB: Equatable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 6, let value = UInt64(s, radix: 16) {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
        } else {
            r = 0.49; g = 0.84; b = 0.70
        }
    }

    init(color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(srgbRed: 0.49, green: 0.84, blue: 0.7, alpha: 1)
        r = Double(ns.redComponent)
        g = Double(ns.greenComponent)
        b = Double(ns.blueComponent)
    }

    var hex: String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }

    func mixed(with other: RGB, _ amount: Double) -> RGB {
        let t = max(0, min(1, amount))
        return RGB(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    func lighter(_ amount: Double) -> RGB { mixed(with: RGB(r: 1, g: 1, b: 1), amount) }
    /// Darkens towards a deep plum rather than black, which keeps pastel shading friendly.
    func darker(_ amount: Double) -> RGB { mixed(with: RGB(r: 0.12, g: 0.09, b: 0.2), amount) }
}

extension Color {
    init(hex: String) { self = RGB(hex: hex).color }
}

enum PetPalette {
    struct Swatch: Identifiable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    static let swatches: [Swatch] = [
        Swatch(name: "Mint", hex: "#7ED6B2"),
        Swatch(name: "Sky", hex: "#8EC9F5"),
        Swatch(name: "Lavender", hex: "#B9A6F2"),
        Swatch(name: "Bubblegum", hex: "#F7A8D8"),
        Swatch(name: "Coral", hex: "#FF9B8A"),
        Swatch(name: "Peach", hex: "#FFC08A"),
        Swatch(name: "Lemon", hex: "#F5D76E"),
        Swatch(name: "Sage", hex: "#A9C79E"),
    ]
}
