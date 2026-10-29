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

    /// README banner: every species in its own palette and gear.
    static func exportLineup(to path: String) {
        write(PetLineup(), scale: 2, to: path)
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

struct PetLineup: View {
    private struct Member: Identifiable {
        let species: PetSpecies
        let palette: String
        var head: HeadGear = .none
        var hands: HandGear = .none
        var neck: NeckGear = .none
        var mood: PetMood = .idle
        var id: PetSpecies { species }
    }

    private let members: [Member] = [
        Member(species: .blob, palette: "mint", head: .sweatband, hands: .dumbbells),
        Member(species: .booty, palette: "peach", head: .sweatband),
        Member(species: .kitty, palette: "lavender", head: .headphones),
        Member(species: .bunny, palette: "bubblegum", head: .cap, mood: .happy),
        Member(species: .bear, palette: "caramel", hands: .kettlebell),
        Member(species: .panda, palette: "graphite", head: .shades),
        Member(species: .fox, palette: "tangerine", neck: .towel),
        Member(species: .puppy, palette: "honey", head: .sweatband, mood: .happy),
        Member(species: .hamster, palette: "blush", hands: .bottle),
        Member(species: .penguin, palette: "midnight", neck: .medal),
        Member(species: .frog, palette: "matcha", head: .cap),
        Member(species: .chick, palette: "lemon", neck: .whistle, mood: .happy),
        Member(species: .axolotl, palette: "cottonCandy", head: .crown),
        Member(species: .dino, palette: "forest", hands: .trophy, mood: .happy),
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach([0, 7], id: \.self) { start in
                HStack(spacing: 10) {
                    ForEach(members[start..<start + 7]) { member in
                        cell(member)
                    }
                }
            }
        }
        .padding(16)
    }

    private func cell(_ m: Member) -> some View {
        let palette = PetPalette.all.first { $0.id == m.palette } ?? PetPalette.all[0]
        let look = PetLook(species: m.species, color: RGB(hex: palette.body), belly: RGB(hex: palette.belly),
                           head: m.head, hands: m.hands, neck: m.neck)
        let t = m.species == .booty ? PetPainter.showcaseTime(for: .booty) : (m.mood == .happy ? 0.3 : 1.2)
        return VStack(spacing: 2) {
            PetCanvas(look: look, mood: m.mood, t: t, effects: false)
                .frame(width: 112, height: 112)
            Text(m.species.label)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(white: 0.5))
            Text(m.species.role)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundColor(Color(white: 0.58))
        }
        .frame(width: 124)
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
