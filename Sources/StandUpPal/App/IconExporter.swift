import AppKit
import SwiftUI

/// Renders the app icon from the same painter as the pet, so there are no image assets.
@MainActor
enum IconExporter {
    static func export(to path: String) {
        write(AppIconArtwork(), scale: 1, to: path)
    }

    /// Dev helper: every species × mood plus the accessories, for eyeballing the art.
    static func exportGallery(to path: String) {
        write(PetGallery(), scale: 2, to: path)
    }

    private static func write<V: View>(_ view: V, scale: CGFloat, to path: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cgImage = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("Could not render the icon\n".utf8))
            exit(1)
        }
        do {
            try png.write(to: URL(fileURLWithPath: path))
        } catch {
            FileHandle.standardError.write(Data("Could not write \(path): \(error)\n".utf8))
            exit(1)
        }
    }
}

struct PetGallery: View {
    private struct Tile: Identifiable {
        let id = UUID()
        let look: PetLook
        let mood: PetMood
        let t: Double
    }

    private func palette(_ index: Int) -> PetPalette { PetPalette.all[(index * 5 + 3) % PetPalette.all.count] }

    private func look(_ species: PetSpecies, _ paletteID: String, head: HeadGear = .none, hands: HandGear = .none,
                      neck: NeckGear = .none) -> PetLook {
        let p = PetPalette.all.first { $0.id == paletteID } ?? PetPalette.all[0]
        return PetLook(species: species, color: RGB(hex: p.body), belly: RGB(hex: p.belly), head: head, hands: hands, neck: neck)
    }

    private var rows: [[Tile]] {
        let species = PetSpecies.allCases
        let lineup = species.enumerated().map { index, s in
            PetLook(species: s, color: RGB(hex: palette(index).body), belly: RGB(hex: palette(index).belly))
        }
        var rows: [[Tile]] = []
        rows.append(lineup.prefix(7).map { Tile(look: $0, mood: .idle, t: 1.2) })
        rows.append(lineup.dropFirst(7).map { Tile(look: $0, mood: .idle, t: 1.2) })
        rows.append(lineup.prefix(7).map { Tile(look: $0, mood: .happy, t: 0.3) })
        rows.append(lineup.dropFirst(7).map { Tile(look: $0, mood: .happy, t: 0.3) })
        let booty = look(.booty, "peach", head: .sweatband)
        rows.append([Tile(look: booty, mood: .idle, t: 1.2), Tile(look: booty, mood: .idle, t: 9.5),
                     Tile(look: booty, mood: .happy, t: 2.3), Tile(look: booty, mood: .exercise, t: 5.2),
                     Tile(look: booty, mood: .celebrate, t: 2.4), Tile(look: look(.booty, "cherry", hands: .dumbbells), mood: .exercise, t: 6),
                     Tile(look: look(.booty, "lavender", head: .crown), mood: .idle, t: 9.8)])
        rows.append(HeadGear.allCases.map { Tile(look: look(.blob, "mint", head: $0), mood: .idle, t: 1.2) }
                    + [Tile(look: look(.frog, "matcha", head: .cap), mood: .idle, t: 1.2)])
        rows.append(HandGear.allCases.dropFirst().map { Tile(look: look(.bear, "caramel", hands: $0), mood: .idle, t: 1.2) }
                    + [Tile(look: look(.bear, "caramel", hands: .dumbbells), mood: .exercise, t: 0.5),
                       Tile(look: look(.bear, "caramel", hands: .trophy), mood: .celebrate, t: 0.3),
                       Tile(look: look(.chick, "lemon", hands: .bottle), mood: .happy, t: 0.3)])
        rows.append(NeckGear.allCases.dropFirst().map { Tile(look: look(.kitty, "sky", neck: $0), mood: .idle, t: 1.2) }
                    + [Tile(look: look(.penguin, "midnight", head: .cap, hands: .dumbbells, neck: .medal), mood: .exercise, t: 1),
                       Tile(look: look(.fox, "tangerine", head: .headphones, neck: .towel), mood: .idle, t: 1.2),
                       Tile(look: look(.panda, "graphite", head: .shades, hands: .kettlebell), mood: .idle, t: 1.2),
                       Tile(look: look(.axolotl, "bubblegum", head: .crown, neck: .medal), mood: .happy, t: 0.3)])
        rows.append(["graphite", "midnight", "galaxy", "cocoa", "berry", "forest", "snow"].enumerated().map { index, id in
            Tile(look: look([.blob, .kitty, .bunny, .bear, .fox, .dino, .hamster][index], id), mood: .idle, t: 1.2)
        })
        rows.append(PetMood.allCases.map { Tile(look: look(.puppy, "caramel", head: .sweatband), mood: $0, t: 0.3) })
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { tile in
                        PetCanvas(look: tile.look, mood: tile.mood, t: tile.t)
                            .frame(width: 110, height: 110)
                    }
                }
            }
            HStack(spacing: 10) {
                ForEach(Array(PetSpecies.allCases.enumerated()), id: \.offset) { index, species in
                    PetCanvas(look: PetLook(species: species, color: RGB(hex: palette(index).body), belly: RGB(hex: palette(index).belly),
                                            head: .sweatband),
                              mood: .idle, t: 0, effects: false, zoom: 1.14)
                        .frame(width: 21, height: 21)
                        .background(Color(white: 0.92))
                }
            }
        }
        .padding(12)
        .background(Color.white)
    }
}

struct AppIconArtwork: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: "#FFF6DD"), Color(hex: "#FFCFB8")],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 186, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: 5)
                )
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            PetCanvas(look: PetLook(species: .blob, color: RGB(hex: "#7ED6B2"), head: .sweatband),
                      mood: .happy, t: 0.31, effects: false)
                .frame(width: 720, height: 720)
                .offset(y: 4)
        }
        .frame(width: 1024, height: 1024)
    }
}
