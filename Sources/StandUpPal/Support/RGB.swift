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

    /// Perceived brightness, 0 (black) to 1 (white).
    var luminance: Double { 0.299 * r + 0.587 * g + 0.114 * b }

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

/// Two-tone looks for the pet: a body colour and a belly/face colour. The app's
/// accent colour follows the body.
struct PetPalette: Identifiable, Equatable {
    let id: String
    let body: String
    let belly: String

    var name: String {
        switch id {
        case "mint": return tr("Mint", "М'ята", "Мята")
        case "sky": return tr("Sky", "Небо", "Небо")
        case "lavender": return tr("Lavender", "Лаванда", "Лаванда")
        case "bubblegum": return tr("Bubblegum", "Жуйка", "Жвачка")
        case "coral": return tr("Coral", "Корал", "Коралл")
        case "peach": return tr("Peach", "Персик", "Персик")
        case "lemon": return tr("Lemon", "Лимон", "Лимон")
        case "sage": return tr("Sage", "Шавлія", "Шалфей")
        case "lilac": return tr("Lilac", "Бузок", "Сирень")
        case "snow": return tr("Snow", "Сніжок", "Снежок")
        case "caramel": return tr("Caramel", "Карамель", "Карамель")
        case "blush": return tr("Blush", "Рум'янець", "Румянец")
        case "honey": return tr("Honey", "Мед", "Мёд")
        case "pistachio": return tr("Pistachio", "Фісташка", "Фисташка")
        case "ocean": return tr("Ocean", "Океан", "Океан")
        case "lagoon": return tr("Lagoon", "Лагуна", "Лагуна")
        case "matcha": return tr("Matcha", "Матча", "Матча")
        case "tangerine": return tr("Tangerine", "Мандарин", "Мандарин")
        case "cherry": return tr("Cherry", "Вишня", "Вишня")
        case "grape": return tr("Grape", "Виноград", "Виноград")
        case "berry": return tr("Berry", "Ягідка", "Ягодка")
        case "forest": return tr("Forest", "Ліс", "Лес")
        case "cottonCandy": return tr("Cotton candy", "Цукрова вата", "Сахарная вата")
        case "sunset": return tr("Sunset", "Захід сонця", "Закат")
        case "galaxy": return tr("Galaxy", "Галактика", "Галактика")
        case "cocoa": return tr("Cocoa", "Какао", "Какао")
        case "graphite": return tr("Graphite", "Графіт", "Графит")
        case "midnight": return tr("Midnight", "Опівніч", "Полночь")
        default: return id
        }
    }

    static let all: [PetPalette] = [
        // Soft pastels
        PetPalette(id: "mint", body: "#7ED6B2", belly: "#E4F8EF"),
        PetPalette(id: "sky", body: "#8EC9F5", belly: "#E7F4FF"),
        PetPalette(id: "lavender", body: "#B9A6F2", belly: "#F1ECFF"),
        PetPalette(id: "bubblegum", body: "#F7A8D8", belly: "#FFEAF6"),
        PetPalette(id: "coral", body: "#FF9B8A", belly: "#FFE7E1"),
        PetPalette(id: "peach", body: "#FFC08A", belly: "#FFF1E2"),
        PetPalette(id: "lemon", body: "#F5D76E", belly: "#FFF8DC"),
        PetPalette(id: "sage", body: "#A9C79E", belly: "#EFF5EB"),
        PetPalette(id: "lilac", body: "#D7A8E8", belly: "#F9EDFF"),
        PetPalette(id: "snow", body: "#E9ECF4", belly: "#FFFFFF"),
        PetPalette(id: "caramel", body: "#DDA772", belly: "#F9E8D2"),
        PetPalette(id: "blush", body: "#F2B5B0", belly: "#FDEEEC"),
        PetPalette(id: "honey", body: "#F6B93B", belly: "#FFF2CC"),
        PetPalette(id: "pistachio", body: "#C5DE8A", belly: "#F6FBE7"),
        // Bold and two-tone
        PetPalette(id: "ocean", body: "#4FA3E0", belly: "#D8EEFF"),
        PetPalette(id: "lagoon", body: "#35BDB8", belly: "#D9F5F3"),
        PetPalette(id: "matcha", body: "#8BC34A", belly: "#EAF5DC"),
        PetPalette(id: "tangerine", body: "#FF9940", belly: "#FFE9D1"),
        PetPalette(id: "cherry", body: "#EF5F78", belly: "#FFE1E7"),
        PetPalette(id: "grape", body: "#9A7BE3", belly: "#ECE4FF"),
        PetPalette(id: "berry", body: "#C2508A", belly: "#FBE0EE"),
        PetPalette(id: "forest", body: "#4E9A6B", belly: "#DDF2E3"),
        PetPalette(id: "cottonCandy", body: "#F7B2D3", belly: "#BFE3FF"),
        PetPalette(id: "sunset", body: "#FF8A65", belly: "#FFD677"),
        PetPalette(id: "galaxy", body: "#6B62C9", belly: "#F6B8E6"),
        PetPalette(id: "cocoa", body: "#A77652", belly: "#EED9C4"),
        PetPalette(id: "graphite", body: "#565C70", belly: "#F1F2F6"),
        PetPalette(id: "midnight", body: "#3E4F8F", belly: "#CFDAFF"),
    ]

    static func matching(body: String, belly: String) -> PetPalette? {
        all.first { $0.body.caseInsensitiveCompare(body) == .orderedSame
            && (belly.isEmpty || $0.belly.caseInsensitiveCompare(belly) == .orderedSame) }
    }
}
