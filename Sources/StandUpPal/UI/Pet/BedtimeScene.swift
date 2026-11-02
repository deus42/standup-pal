import SwiftUI

/// A little bed, seen from the foot end, with the pet tucked in up to its chin. Drawn
/// in an 80×60 design space with the floor at the bottom; used on the Dock at night and
/// at the end of the bedtime scene.
struct BedPainter {
    static let size = CGSize(width: 80, height: 60)
    /// Where the pet sits in bed, and how big it is, in bed space.
    static let petCenter = CGPoint(x: 40, y: 27.5)
    static let petSize: Double = 56

    /// The pet as it should look in bed (the caller dresses it for the night).
    let look: PetLook
    let t: Double
    var petInBed = true
    var mood: PetMood = .sleepy
    /// Moves the pet away from its spot (design units), for dropping into bed.
    var petOffset: CGSize = .zero
    /// 0…1: how far the blanket is pulled up.
    var tuck: Double = 1
    var zzz = true

    private let wood = RGB(r: 0.8, g: 0.57, b: 0.38)
    private let quilt = RGB(r: 0.7, g: 0.62, b: 0.95)
    private let linen = RGB(r: 0.98, g: 0.97, b: 0.95)

    /// Draws into `rect`, keeping the bed's proportions and standing it on the rect's bottom.
    func draw(_ context: inout GraphicsContext, in rect: CGRect) {
        let scale = min(rect.width / Self.size.width, rect.height / Self.size.height)
        var g = context
        g.translateBy(x: rect.midX - Self.size.width * scale / 2, y: rect.maxY - Self.size.height * scale)
        g.scaleBy(x: scale, y: scale)
        draw(&g)
    }

    private func draw(_ g: inout GraphicsContext) {
        let edge = wood.darker(0.45).color
        var headboard = Path()
        headboard.move(to: CGPoint(x: 7, y: 52))
        headboard.addLine(to: CGPoint(x: 7, y: 20))
        headboard.addQuadCurve(to: CGPoint(x: 40, y: 8), control: CGPoint(x: 8, y: 8))
        headboard.addQuadCurve(to: CGPoint(x: 73, y: 20), control: CGPoint(x: 72, y: 8))
        headboard.addLine(to: CGPoint(x: 73, y: 52))
        headboard.closeSubpath()
        g.fill(headboard, with: .linearGradient(Gradient(colors: [wood.lighter(0.22).color, wood.color]),
                                                startPoint: CGPoint(x: 40, y: 8), endPoint: CGPoint(x: 40, y: 52)))
        g.stroke(headboard, with: .color(edge), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        var inset = Path()
        inset.move(to: CGPoint(x: 13, y: 44))
        inset.addLine(to: CGPoint(x: 13, y: 22))
        inset.addQuadCurve(to: CGPoint(x: 40, y: 13.5), control: CGPoint(x: 14, y: 13.5))
        inset.addQuadCurve(to: CGPoint(x: 67, y: 22), control: CGPoint(x: 66, y: 13.5))
        inset.addLine(to: CGPoint(x: 67, y: 44))
        g.stroke(inset, with: .color(wood.darker(0.15).color), lineWidth: 1.2)

        let pillow = Path(roundedRect: CGRect(x: 19, y: 25, width: 42, height: 13), cornerRadius: 6.5)
        g.fill(pillow, with: .color(.white))
        g.stroke(pillow, with: .color(Color(white: 0.64)), lineWidth: 1)

        if petInBed {
            var p = g
            p.translateBy(x: Self.petCenter.x - Self.petSize / 2 + petOffset.width, y: Self.petCenter.y - Self.petSize / 2 + petOffset.height)
            PetPainter(look: look, mood: mood, t: t, effects: false)
                .draw(&p, size: CGSize(width: Self.petSize, height: Self.petSize))
        }

        // Pulled up to the chin; it rises and falls with the breathing.
        let breath = petInBed && mood == .sleepy ? sin(t * 1.6) * 0.5 : 0
        let top = 46 - 6.5 * tuck + breath
        var blanket = Path()
        blanket.move(to: CGPoint(x: 3, y: 55))
        blanket.addLine(to: CGPoint(x: 3, y: top + 3))
        blanket.addQuadCurve(to: CGPoint(x: 77, y: top + 3), control: CGPoint(x: 40, y: top - 3))
        blanket.addLine(to: CGPoint(x: 77, y: 55))
        blanket.closeSubpath()
        g.fill(blanket, with: .linearGradient(Gradient(colors: [quilt.lighter(0.2).color, quilt.color]),
                                              startPoint: CGPoint(x: 40, y: top), endPoint: CGPoint(x: 40, y: 55)))
        var inside = g
        inside.clip(to: blanket)
        for row in 0..<3 {
            for col in 0..<12 {
                let x = 5 + Double(col) * 6.4 + (row % 2 == 0 ? 0 : 3.2)
                inside.fill(Path(ellipseIn: CGRect(x: x, y: top + 6 + Double(row) * 4.6, width: 1.8, height: 1.8)),
                            with: .color(.white.opacity(0.6)))
            }
        }
        // The folded-over sheet along the top.
        var fold = Path()
        fold.move(to: CGPoint(x: 3, y: top + 3))
        fold.addQuadCurve(to: CGPoint(x: 77, y: top + 3), control: CGPoint(x: 40, y: top - 3))
        inside.stroke(fold, with: .color(linen.color), lineWidth: 6)
        g.stroke(blanket, with: .color(quilt.darker(0.4).color), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

        let frame = Path(roundedRect: CGRect(x: 1, y: 53, width: 78, height: 4.5), cornerRadius: 2)
        g.fill(frame, with: .color(wood.color))
        g.stroke(frame, with: .color(edge), lineWidth: 1.2)
        for x in [4.0, 71.0] {
            g.fill(Path(roundedRect: CGRect(x: x, y: 57, width: 5, height: 3), cornerRadius: 1), with: .color(wood.darker(0.2).color))
        }

        if petInBed, zzz {
            for i in 0..<3 {
                let phase = (t * 0.3 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                var z = g
                z.opacity = sin(phase * .pi)
                z.draw(Text("z").font(.system(size: 5 + phase * 6, weight: .heavy, design: .rounded)).foregroundColor(Color(white: 0.72)),
                       at: CGPoint(x: 58 + phase * 12 + sin(phase * 6) * 1.5, y: 12 - phase * 13))
            }
        }
    }
}

/// The bedtime story in one card: the pet at its laptop shuts the lid, yawns, walks
/// over to its bed, climbs in and falls asleep as the lamp goes out. Drawn in a
/// 340×140 design space.
struct BedtimeScenePainter {
    static let size = CGSize(width: 340, height: 140)
    static let typingEnd = 1.8, closeEnd = 2.5, yawnEnd = 3.4, walkEnd = 5.4, hopEnd = 6.1
    /// Long enough to see the whole story.
    static let duration = hopEnd + 1.4

    let look: PetLook
    /// Pyjamas while up, a nightcap in bed.
    let dressed: Bool
    /// Seconds since the scene started.
    let elapsed: Double
    /// A free-running clock for idle animation.
    let clock: Double

    private let floorY = 124.0
    private let petSize = 70.0
    private let startX = 52.0
    private let hopHeight = 34.0
    private var bedRect: CGRect {
        // Sized so the pet in bed is as big as the pet standing up.
        let scale = petSize / BedPainter.petSize
        let size = CGSize(width: BedPainter.size.width * scale, height: BedPainter.size.height * scale)
        return CGRect(x: 336 - size.width, y: floorY - size.height, width: size.width, height: size.height)
    }
    private var bedScale: Double { bedRect.width / BedPainter.size.width }
    private var standingY: Double { floorY - 30.5 * petSize / 100 }
    /// Where the walk ends, just before the bed.
    private var walkTo: Double { bedRect.minX - 14 }
    /// The pet's spot in bed, in scene space.
    private var bedSpot: CGPoint {
        CGPoint(x: bedRect.minX + BedPainter.petCenter.x * bedScale, y: bedRect.minY + BedPainter.petCenter.y * bedScale)
    }

    /// The pet's centre along the hop into bed, `k` from 0 to 1.
    private func hopCenter(_ k: Double) -> CGPoint {
        CGPoint(x: walkTo + (bedSpot.x - walkTo) * k, y: standingY + (bedSpot.y - standingY) * k - sin(k * .pi) * hopHeight)
    }

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        var g = context
        let scale = min(size.width / Self.size.width, size.height / Self.size.height)
        g.scaleBy(x: scale, y: scale)

        let asleepFor = elapsed - Self.hopEnd
        let lightsOut = max(0, min(1, (asleepFor - 0.3) / 0.8))
        drawRoom(&g, lightsOut: lightsOut)
        drawDesk(&g, lightsOut: lightsOut)

        // Halfway through the hop the pet is over the bed and drops in behind the blanket.
        let hop = max(0, min(1, (elapsed - Self.walkEnd) / (Self.hopEnd - Self.walkEnd)))
        let inBed = hop >= 0.5
        let tuck = max(0, min(1, asleepFor / 0.5))
        let flight = hopCenter(hop)
        let offset = CGSize(width: (flight.x - bedSpot.x) / bedScale, height: (flight.y - bedSpot.y) / bedScale)
        BedPainter(look: nightLook, t: clock, petInBed: inBed, mood: asleepFor > 0 ? .sleepy : .happy,
                   petOffset: offset, tuck: tuck, zzz: asleepFor > 0.6)
            .draw(&g, in: bedRect)
        if !inBed { drawUpPet(&g) }

        if lightsOut > 0 {
            g.fill(Path(CGRect(origin: .zero, size: Self.size)), with: .color(Color(.sRGB, red: 0.05, green: 0.04, blue: 0.16).opacity(0.4 * lightsOut)))
            drawSky(&g, glow: lightsOut)
        }
    }

    private var homeLook: PetLook { look.dressed(for: dressed ? .home : nil) }
    private var nightLook: PetLook { look.dressed(for: dressed ? .night : nil) }

    // MARK: Room

    private func drawRoom(_ g: inout GraphicsContext, lightsOut: Double) {
        let wall = Gradient(colors: [Color(.sRGB, red: 0.42, green: 0.38, blue: 0.62), Color(.sRGB, red: 0.33, green: 0.3, blue: 0.52)])
        g.fill(Path(CGRect(x: 0, y: 0, width: Self.size.width, height: floorY)),
               with: .linearGradient(wall, startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        let floor = RGB(r: 0.56, g: 0.42, b: 0.33)
        g.fill(Path(CGRect(x: 0, y: floorY, width: Self.size.width, height: Self.size.height - floorY)), with: .color(floor.color))
        g.fill(Path(CGRect(x: 0, y: floorY, width: Self.size.width, height: 1.5)), with: .color(floor.darker(0.3).color))
        for x in stride(from: 30.0, to: Self.size.width, by: 52) {
            g.fill(Path(CGRect(x: x, y: floorY + 1.5, width: 1, height: Self.size.height - floorY)), with: .color(floor.darker(0.15).color))
        }
        // The window, with a night sky.
        let window = CGRect(x: 160, y: 22, width: 50, height: 46)
        g.fill(Path(roundedRect: window.insetBy(dx: -3, dy: -3), cornerRadius: 5), with: .color(Color(white: 0.93)))
        g.fill(Path(roundedRect: window, cornerRadius: 3),
               with: .linearGradient(Gradient(colors: [Color(.sRGB, red: 0.1, green: 0.12, blue: 0.32), Color(.sRGB, red: 0.2, green: 0.2, blue: 0.48)]),
                                     startPoint: CGPoint(x: 0, y: window.minY), endPoint: CGPoint(x: 0, y: window.maxY)))
        drawSky(&g, glow: 0)
        g.fill(Path(CGRect(x: window.midX - 1.2, y: window.minY, width: 2.4, height: window.height)), with: .color(Color(white: 0.93)))
        g.fill(Path(CGRect(x: window.minX, y: window.midY - 1.2, width: window.width, height: 2.4)), with: .color(Color(white: 0.93)))
        // A framed picture of a dumbbell, naturally.
        let frame = CGRect(x: 104, y: 34, width: 22, height: 17)
        g.fill(Path(roundedRect: frame, cornerRadius: 2), with: .color(Color(.sRGB, red: 0.98, green: 0.93, blue: 0.8)))
        g.stroke(Path(roundedRect: frame, cornerRadius: 2), with: .color(Color(.sRGB, red: 0.62, green: 0.45, blue: 0.3)), lineWidth: 1.8)
        g.fill(Path(CGRect(x: 109, y: 41.8, width: 12, height: 1.6)), with: .color(Color(white: 0.5)))
        for x in [108.0, 120.0] {
            g.fill(Path(roundedRect: CGRect(x: x, y: 39, width: 2.4, height: 7), cornerRadius: 1), with: .color(Color(.sRGB, red: 0.36, green: 0.49, blue: 0.98)))
        }
    }

    private func drawSky(_ g: inout GraphicsContext, glow: Double) {
        let moon = CGPoint(x: 196, y: 36)
        if glow > 0 {
            g.fill(Path(ellipseIn: CGRect(x: moon.x - 16, y: moon.y - 16, width: 32, height: 32)),
                   with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 1, green: 0.95, blue: 0.7).opacity(0.35 * glow), .clear]),
                                         center: moon, startRadius: 2, endRadius: 16))
        }
        var crescent = Path(ellipseIn: CGRect(x: moon.x - 6, y: moon.y - 6, width: 12, height: 12))
        crescent = crescent.subtracting(Path(ellipseIn: CGRect(x: moon.x - 3, y: moon.y - 8, width: 12, height: 12)))
        g.fill(crescent, with: .color(Color(.sRGB, red: 1, green: 0.93, blue: 0.62)))
        for (i, star) in [CGPoint(x: 168, y: 30), CGPoint(x: 178, y: 52), CGPoint(x: 202, y: 58), CGPoint(x: 170, y: 60)].enumerated() {
            let twinkle = 0.5 + 0.5 * sin(clock * 2 + Double(i) * 1.7)
            let r = 0.8 + twinkle * 0.7
            g.fill(Path(ellipseIn: CGRect(x: star.x - r, y: star.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.5 + twinkle * 0.5)))
        }
    }

    // MARK: Desk, laptop and lamp

    private func drawDesk(_ g: inout GraphicsContext, lightsOut: Double) {
        let wood = RGB(r: 0.72, g: 0.5, b: 0.34)
        let edge = wood.darker(0.45).color
        for x in [76.0, 140.0] {
            g.fill(Path(CGRect(x: x, y: 103, width: 4, height: floorY - 103)), with: .color(wood.darker(0.15).color))
        }
        let top = Path(roundedRect: CGRect(x: 70, y: 99.5, width: 82, height: 4.5), cornerRadius: 1.5)
        g.fill(top, with: .color(wood.color))
        g.stroke(top, with: .color(edge), lineWidth: 1)

        // The lamp: on until the pet is in bed.
        let lampOn = 1 - lightsOut
        if lampOn > 0 {
            g.fill(Path(ellipseIn: CGRect(x: 108, y: 66, width: 56, height: 50)),
                   with: .radialGradient(Gradient(colors: [Color(.sRGB, red: 1, green: 0.88, blue: 0.55).opacity(0.45 * lampOn), .clear]),
                                         center: CGPoint(x: 136, y: 84), startRadius: 2, endRadius: 28))
        }
        g.fill(Path(ellipseIn: CGRect(x: 130, y: 97, width: 13, height: 3.5)), with: .color(Color(white: 0.35)))
        g.fill(Path(CGRect(x: 135.6, y: 81, width: 1.8, height: 17)), with: .color(Color(white: 0.4)))
        var shade = Path()
        shade.move(to: CGPoint(x: 129, y: 82))
        shade.addLine(to: CGPoint(x: 144, y: 82))
        shade.addLine(to: CGPoint(x: 140.5, y: 72))
        shade.addLine(to: CGPoint(x: 132.5, y: 72))
        shade.closeSubpath()
        let shadeColor = RGB(r: 1, g: 0.86, b: 0.5).lighter(0.2 * lampOn)
        g.fill(shade, with: .color(shadeColor.darker(0.25 * lightsOut).color))
        g.stroke(shade, with: .color(Color(.sRGB, red: 0.6, green: 0.45, blue: 0.25)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))

        // The laptop, seen from the side. The hinge is at the back (right); the lid
        // swings towards the pet and down as it closes.
        let base = Path(roundedRect: CGRect(x: 74, y: 96.6, width: 34, height: 3.2), cornerRadius: 1.4)
        g.fill(base, with: .color(Color(white: 0.72)))
        g.stroke(base, with: .color(Color(white: 0.4)), lineWidth: 0.9)
        let closing = max(0, min(1, (elapsed - Self.typingEnd) / (Self.closeEnd - Self.typingEnd)))
        let eased = closing * closing * (3 - 2 * closing)
        let angle = (78 + (180 - 78) * eased) * .pi / 180
        let hinge = CGPoint(x: 107, y: 97)
        let tip = CGPoint(x: hinge.x + cos(angle) * 30, y: hinge.y - sin(angle) * 30)
        let open = 1 - eased
        if open > 0.02 {
            var glow = Path()
            glow.move(to: CGPoint(x: (hinge.x + tip.x) / 2, y: (hinge.y + tip.y) / 2))
            glow.addLine(to: CGPoint(x: 54, y: 76))
            glow.addLine(to: CGPoint(x: 54, y: 106))
            glow.closeSubpath()
            g.fill(glow, with: .linearGradient(Gradient(colors: [Color(.sRGB, red: 0.55, green: 0.85, blue: 1).opacity(0.32 * open), .clear]),
                                               startPoint: CGPoint(x: 100, y: 90), endPoint: CGPoint(x: 56, y: 90)))
        }
        var lid = Path()
        lid.move(to: hinge)
        lid.addLine(to: tip)
        g.stroke(lid, with: .color(Color(white: 0.4)), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
        g.stroke(lid, with: .color(Color(white: 0.74)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        if open > 0.02 {
            // The screen, on the side facing the pet.
            let nx = -sin(angle) * 1.6, ny = -cos(angle) * 1.6
            var screen = Path()
            screen.move(to: CGPoint(x: hinge.x + nx + cos(angle) * 3, y: hinge.y + ny - sin(angle) * 3))
            screen.addLine(to: CGPoint(x: tip.x + nx - cos(angle) * 2, y: tip.y + ny + sin(angle) * 2))
            g.stroke(screen, with: .color(Color(.sRGB, red: 0.6, green: 0.88, blue: 1).opacity(open)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }
    }

    // MARK: The pet, up and about

    private func drawUpPet(_ g: inout GraphicsContext) {
        var center = CGPoint(x: startX, y: standingY)
        var mood = PetMood.idle
        var motion: ExerciseMotion?
        var t = clock
        var current = homeLook

        switch elapsed {
        case ..<Self.typingEnd:
            motion = .typing
        case ..<Self.closeEnd:
            motion = .closeLid
            t = (elapsed - Self.typingEnd) / (Self.closeEnd - Self.typingEnd)
        case ..<Self.yawnEnd:
            motion = .yawn
        case ..<Self.walkEnd:
            motion = .walk
            let k = (elapsed - Self.yawnEnd) / (Self.walkEnd - Self.yawnEnd)
            center.x = startX + (walkTo - startX) * k
        default:
            // The first half of the hop into bed (the bed draws the second half). The
            // nightcap goes on.
            center = hopCenter(max(0, min(1, (elapsed - Self.walkEnd) / (Self.hopEnd - Self.walkEnd))))
            mood = .happy
            current = nightLook
        }

        var p = g
        p.translateBy(x: center.x - petSize / 2, y: center.y - petSize / 2)
        PetPainter(look: current, mood: mood, t: t, effects: false, motion: motion)
            .draw(&p, size: CGSize(width: petSize, height: petSize))
    }
}

/// The animated scene, starting when the view appears.
struct BedtimeScene: View {
    let look: PetLook
    let dressed: Bool
    let started: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                BedtimeScenePainter(look: look, dressed: dressed, elapsed: timeline.date.timeIntervalSince(started),
                                    clock: timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400))
                    .draw(&context, size: size)
            }
        }
        .aspectRatio(BedtimeScenePainter.size.width / BedtimeScenePainter.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
