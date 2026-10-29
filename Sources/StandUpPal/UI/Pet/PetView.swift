import AppKit
import SwiftUI

/// One frame of the pet at time `t`.
struct PetCanvas: View {
    var look: PetLook
    var mood: PetMood
    var t: Double
    var effects = true
    var zoom = 1.0

    var body: some View {
        Canvas { context, size in
            PetPainter(look: look, mood: mood, t: t, effects: effects, zoom: zoom).draw(&context, size: size)
        }
    }
}

/// The live, animated pet.
struct PetView: View {
    var look: PetLook
    var mood: PetMood
    var animated = true
    var effects = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            PetCanvas(look: look, mood: mood,
                      t: timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400),
                      effects: effects)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(tr("Your pet: \(mood.label)", "Твій улюбленець: \(mood.label)", "Твой питомец: \(mood.label)"))
    }
}

/// Renders small pet images for the menu bar.
@MainActor
enum PetIcon {
    static func image(look: PetLook, mood: PetMood, t: Double, size: CGFloat = 21) -> NSImage? {
        let alert = mood == .alert
        let view = PetCanvas(look: look, mood: mood, t: t, effects: alert, zoom: alert ? 1.0 : 1.14)
            .frame(width: size, height: size)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }
}
