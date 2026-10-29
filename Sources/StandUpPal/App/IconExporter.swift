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
    private let colors = ["#7ED6B2", "#8EC9F5", "#F7A8D8", "#FFC08A"]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(PetSpecies.allCases.enumerated()), id: \.offset) { index, species in
                HStack(spacing: 6) {
                    ForEach(PetMood.allCases) { mood in
                        PetCanvas(look: PetLook(species: species, color: RGB(hex: colors[index]), accessory: .none),
                                  mood: mood, t: 0.3)
                            .frame(width: 110, height: 110)
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(PetAccessory.allCases) { accessory in
                    PetCanvas(look: PetLook(species: .blob, color: RGB(hex: "#B9A6F2"), accessory: accessory),
                              mood: .idle, t: 1.2)
                        .frame(width: 110, height: 110)
                }
                ForEach(PetMood.allCases.prefix(1)) { _ in
                    PetCanvas(look: PetLook(species: .kitty, color: RGB(hex: "#F5D76E"), accessory: .crown),
                              mood: .happy, t: 0.3)
                        .frame(width: 110, height: 110)
                }
            }
            HStack(spacing: 10) {
                ForEach(PetMood.allCases) { mood in
                    PetCanvas(look: PetLook(species: .blob, color: RGB(hex: "#7ED6B2"), accessory: .none),
                              mood: mood, t: 0, effects: mood == .alert, zoom: mood == .alert ? 1 : 1.14)
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
            PetCanvas(look: PetLook(species: .blob, color: RGB(hex: "#7ED6B2"), accessory: .sweatband),
                      mood: .happy, t: 0.31, effects: false)
                .frame(width: 720, height: 720)
                .offset(y: 4)
        }
        .frame(width: 1024, height: 1024)
    }
}
