import SwiftUI

enum PetMood: String, CaseIterable, Identifiable {
    case idle, happy, alert, sleepy, sad, exercise, celebrate
    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle: return tr("Chilling", "Відпочиває", "Отдыхает")
        case .happy: return tr("Happy", "Радіє", "Радуется")
        case .alert: return tr("Calling you", "Кличе тебе", "Зовёт тебя")
        case .sleepy: return tr("Dozing", "Дрімає", "Дремлет")
        case .sad: return tr("Sad", "Сумує", "Грустит")
        case .exercise: return tr("Working out", "Тренується", "Тренируется")
        case .celebrate: return tr("Celebrating", "Святкує", "Празднует")
        }
    }
}

struct PetLook: Equatable {
    var species: PetSpecies
    var color: RGB
    var belly: RGB
    var head: HeadGear
    var hands: HandGear
    var neck: NeckGear

    init(species: PetSpecies, color: RGB, belly: RGB? = nil,
         head: HeadGear = .none, hands: HandGear = .none, neck: NeckGear = .none) {
        self.species = species
        self.color = color
        self.belly = belly ?? color.lighter(0.62)
        self.head = head
        self.hands = hands
        self.neck = neck
    }

    static func from(_ s: AppSettings) -> PetLook {
        PetLook(species: s.petSpecies, color: RGB(hex: s.petColorHex),
                belly: s.petBellyHex.isEmpty ? nil : RGB(hex: s.petBellyHex),
                head: s.petHead, hands: s.petHands, neck: s.petNeck)
    }
}

/// Draws the pet procedurally in a 100×100 design space. `t` is a time in seconds
/// that drives every animation, so the same painter renders live views and icons.
struct PetPainter {
    let look: PetLook
    let mood: PetMood
    let t: Double
    var effects = true
    var zoom: Double = 1

    /// A time at which a still picture shows what makes the species special
    /// (Booty faces away).
    static func showcaseTime(for species: PetSpecies) -> Double {
        species == .booty ? 9.5 : 1.2
    }

    private struct Pose {
        var lift = 0.0
        var sx = 1.0
        var sy = 1.0
        var tilt = 0.0
        var armL = 22.0
        var armR = 22.0
    }

    private let ink = Color(.sRGB, red: 0.17, green: 0.14, blue: 0.25)
    private let blush = Color(.sRGB, red: 1.0, green: 0.5, blue: 0.6)
    private let yellow = Color(.sRGB, red: 1.0, green: 0.84, blue: 0.4)
    private let beakRGB = RGB(r: 1.0, g: 0.67, b: 0.27)
    private let gold = RGB(r: 1.0, g: 0.79, b: 0.24)

    private let bodyRect = CGRect(x: 18, y: 34, width: 64, height: 57)
    private var bodyPath: Path { Path(roundedRect: bodyRect, cornerRadius: 28, style: .continuous) }

    private var species: PetSpecies { look.species }
    /// Pandas wear the palette on their patches; their body is the light tone.
    private var bodyRGB: RGB { species == .panda ? look.belly : look.color }
    private var outline: Color { look.color.darker(0.5).color }
    /// Dark bodies get a light face so the eyes stay readable.
    private var lightFaceMask: Bool { bodyRGB.luminance < 0.45 && species != .penguin && species != .panda }

    private var eyeCenters: [CGPoint] {
        switch species {
        case .frog: return [CGPoint(x: 35.5, y: 36.5), CGPoint(x: 64.5, y: 36.5)]
        case .axolotl: return [CGPoint(x: 36, y: 58), CGPoint(x: 64, y: 58)]
        default: return [CGPoint(x: 38.5, y: 57.5), CGPoint(x: 61.5, y: 57.5)]
        }
    }

    private var mouthY: Double {
        switch species {
        case .frog: return 60
        case .bear, .puppy: return 69
        default: return 66.5
        }
    }

    // MARK: Entry

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height) / 100 * zoom
        var ctx = context
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: -50, y: -(50 + (zoom - 1) * 45))

        let facing = turn()
        var p = pose(back: facing.back)
        p.sx *= facing.squash

        let liftFactor = min(1, p.lift / 30)
        let shadowWidth = 50 * (1 - liftFactor * 0.5)
        ctx.fill(Path(ellipseIn: CGRect(x: 50 - shadowWidth / 2, y: 90, width: shadowWidth, height: 6)),
                 with: .color(.black.opacity(0.14 * (1 - liftFactor * 0.6))))

        var body = ctx
        body.translateBy(x: 50, y: 91 - p.lift)
        body.rotate(by: .degrees(p.tilt))
        body.scaleBy(x: p.sx, y: p.sy)
        body.translateBy(x: -50, y: -91)

        drawTail(&body)
        drawTopFeatures(&body)
        arm(&body, left: true, angle: p.armL)
        arm(&body, left: false, angle: p.armR)
        drawFeet(&body)
        if facing.back {
            drawBodyBack(&body)
        } else {
            drawBody(&body)
            drawFace(&body)
            drawNeckGear(&body)
        }
        drawHeadGear(&body, back: facing.back)
        drawHeldGear(&body, pose: p)
        if effects { drawEffects(&ctx, pose: p, back: facing.back) }
    }

    /// Booty turns round now and then for a wiggle. `squash` narrows the body around
    /// each turn so it reads as spinning.
    private func turn() -> (back: Bool, squash: Double) {
        guard species == .booty else { return (false, 1) }
        let cycle: Double, start: Double, end: Double
        switch mood {
        case .idle: (cycle, start, end) = (12, 8, 11)
        case .happy, .celebrate: (cycle, start, end) = (3.2, 1.6, 3.2)
        case .exercise: (cycle, start, end) = (8, 4, 8)
        default: return (false, 1)
        }
        let phase = (t.truncatingRemainder(dividingBy: cycle) + cycle).truncatingRemainder(dividingBy: cycle)
        let back = phase >= start && phase < end
        let edges = [start, end, start + cycle, end - cycle]
        let distance = edges.map { abs(phase - $0) }.min() ?? 1
        let squash = distance < 0.18 ? 0.55 + 0.45 * distance / 0.18 : 1
        return (back, squash)
    }

    private func pose(back: Bool) -> Pose {
        var p = Pose()
        switch mood {
        case .idle:
            let b = sin(t * 2.0)
            p.sy = 1 + b * 0.022
            p.sx = 1 - b * 0.014
            p.tilt = back ? sin(t * 9) * 7 : sin(t * 0.8) * 2
            p.armL = 22 + sin(t * 2.0) * 5
            p.armR = 22 + sin(t * 2.0 + 0.6) * 5
        case .happy:
            let phase = (t * 1.6).truncatingRemainder(dividingBy: 1)
            let hop = sin(phase * .pi)
            p.lift = hop * 6
            p.sy = 1 + hop * 0.05
            p.sx = 1 - hop * 0.03
            p.armL = 50 + hop * 60
            p.armR = 50 + hop * 60
            if back { p.tilt = sin(t * 10) * 8 }
        case .celebrate:
            let phase = (t * 2.0).truncatingRemainder(dividingBy: 1)
            let hop = sin(phase * .pi)
            p.lift = hop * 11
            p.sy = 1 + hop * 0.06
            p.sx = 1 - hop * 0.04
            p.armL = 150 + sin(t * 12) * 18
            p.armR = 150 + sin(t * 12 + 1.5) * 18
            p.tilt = back ? sin(t * 10) * 9 : sin(t * 4) * 4
        case .alert:
            let phase = (t * 2.0).truncatingRemainder(dividingBy: 1)
            let hop = sin(phase * .pi)
            let land = max(0, 1 - min(phase, 1 - phase) / 0.1)
            p.lift = hop * 11
            p.sy = 1 + hop * 0.05 - land * 0.1
            p.sx = 1 - hop * 0.03 + land * 0.08
            p.armL = 30
            p.armR = 140 + sin(t * 16) * 28
        case .sleepy:
            let b = sin(t * 1.0)
            p.sy = 0.95 + b * 0.025
            p.sx = 1.03 - b * 0.012
            p.tilt = 5
            p.armL = 10
            p.armR = 10
        case .sad:
            p.sy = 0.95 + sin(t * 1.3) * 0.01
            p.sx = 1.03
            p.tilt = -2
            p.armL = 6
            p.armR = 6
        case .exercise:
            let c = (sin(t * 3.4) + 1) / 2
            p.sy = 1 - c * 0.15
            p.sx = 1 + c * 0.08
            p.armL = 90 + (1 - c) * 70
            p.armR = 90 + (1 - c) * 70
        }
        // Holding something: keep it clear of the body.
        if look.hands != .none, p.armL < 60 {
            p.armL += 9
            p.armR += 9
        }
        return p
    }

    // MARK: Behind the body

    private func drawTail(_ g: inout GraphicsContext) {
        let fill = bodyRGB.color
        switch species {
        case .kitty:
            let sway = sin(t * 1.6) * 3
            var tail = Path()
            tail.move(to: CGPoint(x: 72, y: 84))
            tail.addCurve(to: CGPoint(x: 90 + sway, y: 61), control1: CGPoint(x: 92, y: 87), control2: CGPoint(x: 97, y: 72))
            g.stroke(tail, with: .color(outline), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            g.stroke(tail, with: .color(fill), style: StrokeStyle(lineWidth: 5.4, lineCap: .round))
        case .fox:
            var tail = g
            tail.translateBy(x: 76, y: 84)
            tail.rotate(by: .degrees(42 + sin(t * 1.4) * 6))
            let shape = Path(ellipseIn: CGRect(x: -7.5, y: -30, width: 15, height: 31))
            tail.fill(shape, with: .color(fill))
            var tip = tail
            tip.clip(to: shape)
            tip.fill(Path(CGRect(x: -9, y: -31, width: 18, height: 10)), with: .color(look.belly.color))
            tail.stroke(shape, with: .color(outline), lineWidth: 2)
        case .dino:
            let wag = sin(t * 1.5) * 2
            var tail = Path()
            tail.move(to: CGPoint(x: 72, y: 75))
            tail.addQuadCurve(to: CGPoint(x: 97, y: 73 + wag), control: CGPoint(x: 88, y: 83))
            tail.addQuadCurve(to: CGPoint(x: 74, y: 89), control: CGPoint(x: 91, y: 90))
            tail.closeSubpath()
            g.fill(tail, with: .color(fill))
            g.stroke(tail, with: .color(outline), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        case .puppy:
            var tail = g
            tail.translateBy(x: 79, y: 80)
            tail.rotate(by: .degrees(35 + sin(t * 10) * 16))
            let shape = Path(roundedRect: CGRect(x: -2.7, y: -13, width: 5.4, height: 14), cornerRadius: 2.7)
            tail.fill(shape, with: .color(fill))
            tail.stroke(shape, with: .color(outline), lineWidth: 1.8)
        default:
            break
        }
    }

    private func drawTopFeatures(_ g: inout GraphicsContext) {
        let fill = bodyRGB.color
        let innerEar = blush.opacity(0.55)
        let coveredTop = look.head == .cap || look.head == .crown

        switch species {
        case .blob, .booty:
            guard !coveredTop else { break }
            let sway = sin(t * 2.3) * (mood == .alert ? 5 : 2.5)
            var stem = Path()
            stem.move(to: CGPoint(x: 50, y: 36))
            stem.addQuadCurve(to: CGPoint(x: 52 + sway, y: 19.5), control: CGPoint(x: 47.5, y: 27))
            g.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            let ball = CGRect(x: 52 + sway - 4.6, y: 14.6, width: 9.2, height: 9.2)
            g.fill(Path(ellipseIn: ball), with: .color(species == .booty ? blush : yellow))
            g.stroke(Path(ellipseIn: ball), with: .color(outline), lineWidth: 1.7)
        case .kitty, .fox:
            let fox = species == .fox
            for side in [-1.0, 1.0] {
                let twitch = side > 0 ? max(0, sin(t * 1.7) - 0.85) * 45 : 0
                var e = g
                e.translateBy(x: 50 + side * (fox ? 21 : 20), y: 42)
                e.rotate(by: .degrees(side * ((fox ? 17 : 14) + twitch)))
                let w = fox ? 12.5 : 10.5
                let h = fox ? 23.0 : 19.0
                var ear = Path()
                ear.move(to: CGPoint(x: -w, y: 5))
                ear.addLine(to: CGPoint(x: 0, y: -h))
                ear.addLine(to: CGPoint(x: w, y: 5))
                ear.closeSubpath()
                e.fill(ear, with: .color(fill))
                if fox {
                    var tip = e
                    tip.clip(to: ear)
                    tip.fill(Path(CGRect(x: -w, y: -h - 1, width: 2 * w, height: 10)), with: .color(look.color.darker(0.4).color))
                }
                e.stroke(ear, with: .color(outline), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                var inner = Path()
                inner.move(to: CGPoint(x: -w * 0.48, y: 1))
                inner.addLine(to: CGPoint(x: 0, y: -h * 0.58))
                inner.addLine(to: CGPoint(x: w * 0.48, y: 1))
                inner.closeSubpath()
                e.fill(inner, with: fox ? .color(look.belly.color) : .color(innerEar))
            }
        case .bunny:
            for side in [-1.0, 1.0] {
                let droop = (mood == .sad || mood == .sleepy) && side > 0 ? 55.0 : 0
                let wiggle = sin(t * 2 + side) * 3
                var e = g
                e.translateBy(x: 50 + side * 10, y: 39)
                e.rotate(by: .degrees(side * (10 + droop) + wiggle))
                let ear = CGRect(x: -6.5, y: -33, width: 13, height: 37)
                e.fill(Path(ellipseIn: ear), with: .color(fill))
                e.stroke(Path(ellipseIn: ear), with: .color(outline), lineWidth: 2.2)
                e.fill(Path(ellipseIn: CGRect(x: -3.2, y: -27, width: 6.4, height: 24)), with: .color(innerEar))
            }
        case .bear, .panda, .hamster:
            let radius: Double = species == .hamster ? 7 : (species == .panda ? 9 : 9.5)
            let spread: Double = species == .hamster ? 20 : 22
            for side in [-1.0, 1.0] {
                let center = CGPoint(x: 50 + side * spread, y: species == .hamster ? 40 : 39)
                let ear = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                let earFill = species == .panda ? look.color.color : fill
                g.fill(Path(ellipseIn: ear), with: .color(earFill))
                g.stroke(Path(ellipseIn: ear), with: .color(outline), lineWidth: 2.2)
                if species == .bear {
                    g.fill(Path(ellipseIn: ear.insetBy(dx: 5, dy: 5)), with: .color(look.color.darker(0.18).color))
                } else if species == .hamster {
                    g.fill(Path(ellipseIn: ear.insetBy(dx: 2.6, dy: 2.6)), with: .color(innerEar))
                }
            }
        case .chick:
            guard !coveredTop else { break }
            var tuft = g
            tuft.translateBy(x: 50, y: 36)
            tuft.rotate(by: .degrees(sin(t * 2.2) * 6))
            for angle in [-30.0, 0, 30] {
                var feather = tuft
                feather.rotate(by: .degrees(angle))
                let shape = Path(ellipseIn: CGRect(x: -2.5, y: -11.5, width: 5, height: 12))
                feather.fill(shape, with: .color(fill))
                feather.stroke(shape, with: .color(outline), lineWidth: 1.6)
            }
        case .dino:
            let spike = look.color.darker(0.22).color
            for (x, base, height) in [(36.0, 36.5, 9.5), (50.0, 34.5, 12.5), (64.0, 36.5, 9.5)] {
                var s = Path()
                s.move(to: CGPoint(x: x - 6, y: base + 4))
                s.addQuadCurve(to: CGPoint(x: x, y: base - height), control: CGPoint(x: x - 3.5, y: base - height * 0.4))
                s.addQuadCurve(to: CGPoint(x: x + 6, y: base + 4), control: CGPoint(x: x + 3.5, y: base - height * 0.4))
                s.closeSubpath()
                g.fill(s, with: .color(spike))
                g.stroke(s, with: .color(outline), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
        case .frog:
            for e in eyeCenters {
                let dome = Path(ellipseIn: CGRect(x: e.x - 10.5, y: e.y - 10, width: 21, height: 21))
                g.fill(dome, with: .color(bodyRGB.lighter(0.18).color))
                g.stroke(dome, with: .color(outline), lineWidth: 2.4)
            }
        case .axolotl:
            let gill = look.color.mixed(with: RGB(r: 1, g: 0.5, b: 0.66), 0.65)
            for side in [-1.0, 1.0] {
                for (i, (dy, angle)) in [(45.0, -38.0), (52.0, -4.0), (59.0, 30.0)].enumerated() {
                    var f = g
                    f.translateBy(x: 50 + side * 28, y: dy)
                    f.scaleBy(x: side, y: 1)
                    f.rotate(by: .degrees(angle + sin(t * 2.4 + Double(i)) * 6))
                    let shape = Path(roundedRect: CGRect(x: -1, y: -3, width: 14, height: 6), cornerRadius: 3)
                    f.fill(shape, with: .color(gill.color))
                    f.stroke(shape, with: .color(gill.darker(0.4).color), lineWidth: 1.4)
                    var vein = Path()
                    vein.move(to: CGPoint(x: 2, y: 0))
                    vein.addLine(to: CGPoint(x: 10.5, y: 0))
                    f.stroke(vein, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                }
            }
        case .puppy, .penguin:
            break
        }
    }

    private func arm(_ g: inout GraphicsContext, left: Bool, angle: Double) {
        var a = g
        a.translateBy(x: left ? 23 : 77, y: 63)
        a.rotate(by: .degrees(left ? angle : -angle))
        let wing = species == .chick || species == .penguin
        let rect = wing ? CGRect(x: -4.7, y: -3, width: 9.4, height: 17) : CGRect(x: -4.2, y: -3, width: 8.4, height: 18)
        let shape = Path(roundedRect: rect, cornerRadius: wing ? 4.7 : 4.2)
        let fill: RGB = species == .panda ? look.color : bodyRGB.darker(wing ? 0.1 : 0.06)
        a.fill(shape, with: .color(fill.color))
        a.stroke(shape, with: .color(outline), lineWidth: 1.7)
    }

    private func drawFeet(_ g: inout GraphicsContext) {
        let fill: RGB
        switch species {
        case .chick, .penguin: fill = beakRGB
        case .panda: fill = look.color.darker(0.08)
        default: fill = bodyRGB.darker(0.22)
        }
        let wide = species == .frog
        for x in wide ? [31.0, 55.0] : [33.5, 54.5] {
            let foot = CGRect(x: x, y: 85.5, width: wide ? 14 : 12, height: 8)
            g.fill(Path(ellipseIn: foot), with: .color(fill.color))
            g.stroke(Path(ellipseIn: foot), with: .color(species == .chick || species == .penguin ? beakRGB.darker(0.35).color : outline),
                     lineWidth: 1.7)
        }
    }

    // MARK: Body

    private var bodyGradient: GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [bodyRGB.lighter(0.25).color, bodyRGB.color, bodyRGB.darker(0.08).color]),
                        startPoint: CGPoint(x: 50, y: 34), endPoint: CGPoint(x: 50, y: 91))
    }

    private func drawBody(_ g: inout GraphicsContext) {
        let path = bodyPath
        g.fill(path, with: bodyGradient)

        var inside = g
        inside.clip(to: path)
        switch species {
        case .penguin:
            inside.fill(Path(ellipseIn: CGRect(x: 27, y: 63, width: 46, height: 36)), with: .color(look.belly.color))
        case .panda:
            inside.fill(Path(ellipseIn: CGRect(x: 31, y: 68, width: 38, height: 28)), with: .color(.white.opacity(0.4)))
        default:
            inside.fill(Path(ellipseIn: CGRect(x: 30, y: 68, width: 40, height: 30)), with: .color(look.belly.color.opacity(0.88)))
        }
        if lightFaceMask {
            inside.fill(Path(ellipseIn: CGRect(x: 25, y: 46, width: 50, height: 29)), with: .color(look.belly.color))
        }
        switch species {
        case .penguin:
            for rect in [CGRect(x: 24, y: 44, width: 30, height: 30), CGRect(x: 46, y: 44, width: 30, height: 30),
                         CGRect(x: 30, y: 57, width: 40, height: 20)] {
                inside.fill(Path(ellipseIn: rect), with: .color(look.belly.color))
            }
        case .fox:
            for rect in [CGRect(x: 21, y: 60, width: 27, height: 17), CGRect(x: 52, y: 60, width: 27, height: 17),
                         CGRect(x: 38, y: 63, width: 24, height: 14)] {
                inside.fill(Path(ellipseIn: rect), with: .color(look.belly.color))
            }
        default:
            break
        }

        g.stroke(path, with: .color(outline), lineWidth: 2.4)
        shine(&g, mirrored: false)

        if species == .puppy {
            for side in [-1.0, 1.0] {
                var e = g
                e.translateBy(x: 50 + side * 22, y: 39)
                e.scaleBy(x: side, y: 1)
                e.rotate(by: .degrees(10 + sin(t * 1.8 + side) * 4 + (mood == .sad ? 12 : 0)))
                var ear = Path()
                ear.move(to: CGPoint(x: -3, y: 0))
                ear.addCurve(to: CGPoint(x: 6, y: 25), control1: CGPoint(x: 9, y: -2), control2: CGPoint(x: 14, y: 20))
                ear.addCurve(to: CGPoint(x: -3, y: 0), control1: CGPoint(x: -1, y: 30), control2: CGPoint(x: -8, y: 12))
                ear.closeSubpath()
                e.fill(ear, with: .color(look.color.darker(0.2).color))
                e.stroke(ear, with: .color(outline), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }

    private func shine(_ g: inout GraphicsContext, mirrored: Bool) {
        var shine = g
        shine.translateBy(x: mirrored ? 69.5 : 30.5, y: 43.5)
        shine.rotate(by: .degrees(mirrored ? 30 : -30))
        shine.fill(Path(ellipseIn: CGRect(x: -6, y: -2.8, width: 12, height: 5.6)), with: .color(.white.opacity(0.55)))
    }

    /// Booty from behind: a round little peach.
    private func drawBodyBack(_ g: inout GraphicsContext) {
        let path = bodyPath
        g.fill(path, with: bodyGradient)
        let wiggle = mood == .exercise ? 0 : sin(t * 9) * 1.1

        var inside = g
        inside.clip(to: path)
        let cheek = bodyRGB.lighter(0.16).color
        inside.fill(Path(ellipseIn: CGRect(x: 29, y: 68.5 + wiggle, width: 22, height: 25)), with: .color(cheek))
        inside.fill(Path(ellipseIn: CGRect(x: 49, y: 68.5 - wiggle, width: 22, height: 25)), with: .color(cheek))
        inside.fill(Path(ellipseIn: CGRect(x: 33, y: 80 + wiggle, width: 11, height: 6.5)), with: .color(blush.opacity(0.42)))
        inside.fill(Path(ellipseIn: CGRect(x: 56, y: 80 - wiggle, width: 11, height: 6.5)), with: .color(blush.opacity(0.42)))
        inside.fill(Path(ellipseIn: CGRect(x: 34, y: 72 + wiggle, width: 8, height: 4)), with: .color(.white.opacity(0.5)))
        inside.fill(Path(ellipseIn: CGRect(x: 57, y: 72 - wiggle, width: 8, height: 4)), with: .color(.white.opacity(0.5)))

        g.stroke(path, with: .color(outline), lineWidth: 2.4)

        var crease = Path()
        crease.move(to: CGPoint(x: 50, y: 75))
        crease.addQuadCurve(to: CGPoint(x: 50, y: 91), control: CGPoint(x: 48.6, y: 84))
        g.stroke(crease, with: .color(outline), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
        for side in [-1.0, 1.0] {
            let dy = side < 0 ? wiggle : -wiggle
            var contour = Path()
            contour.move(to: CGPoint(x: 50 + side * 18.5, y: 83 + dy))
            contour.addQuadCurve(to: CGPoint(x: 50 + side * 1.2, y: 89.8), control: CGPoint(x: 50 + side * 14, y: 92 + dy))
            g.stroke(contour, with: .color(outline.opacity(0.5)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        shine(&g, mirrored: true)
    }

    // MARK: Face

    private func drawFace(_ g: inout GraphicsContext) {
        let eyes = eyeCenters

        if species == .panda {
            for (i, e) in eyes.enumerated() {
                var patch = g
                patch.translateBy(x: e.x, y: e.y + 0.5)
                patch.rotate(by: .degrees(i == 0 ? 28 : -28))
                patch.fill(Path(ellipseIn: CGRect(x: -6.8, y: -8.4, width: 13.6, height: 16.8)), with: .color(look.color.color))
            }
        }
        if species == .puppy {
            g.fill(Path(ellipseIn: CGRect(x: 53.5, y: 48.5, width: 16, height: 17)), with: .color(look.color.darker(0.14).color))
        }
        if species == .hamster {
            for x in [22.0, 60.0] {
                g.fill(Path(ellipseIn: CGRect(x: x, y: 58, width: 18, height: 14)), with: .color(look.belly.color))
            }
        }

        let blushOpacity = (mood == .happy || mood == .celebrate) ? 0.68 : 0.45
        let cheekY: Double = species == .frog ? 57 : 63
        let cheekXs: [Double] = species == .axolotl ? [24.5, 65.5] : [26.5, 63.5]
        for x in cheekXs {
            g.fill(Path(ellipseIn: CGRect(x: x, y: cheekY, width: 10, height: 6)), with: .color(blush.opacity(blushOpacity)))
        }

        drawNose(&g)
        if look.head != .shades { drawEyes(&g, eyes) }
        drawMouth(&g)
    }

    private func drawNose(_ g: inout GraphicsContext) {
        switch species {
        case .bear:
            g.fill(Path(ellipseIn: CGRect(x: 40, y: 61, width: 20, height: 14.5)), with: .color(look.belly.color))
            g.fill(Path(ellipseIn: CGRect(x: 46.8, y: 61.8, width: 6.4, height: 4.4)), with: .color(ink))
        case .puppy:
            g.fill(Path(ellipseIn: CGRect(x: 39.5, y: 60.5, width: 21, height: 15)), with: .color(look.belly.color))
            g.fill(Path(ellipseIn: CGRect(x: 46.2, y: 61.2, width: 7.6, height: 5.2)), with: .color(ink))
            g.fill(Path(ellipseIn: CGRect(x: 47.6, y: 61.8, width: 2.4, height: 1.5)), with: .color(.white.opacity(0.8)))
        case .kitty:
            var nose = Path()
            nose.move(to: CGPoint(x: 48.3, y: 62.2))
            nose.addLine(to: CGPoint(x: 51.7, y: 62.2))
            nose.addLine(to: CGPoint(x: 50, y: 64.2))
            nose.closeSubpath()
            g.fill(nose, with: .color(blush))
            for side in [-1.0, 1.0] {
                for (dy, spread) in [(0.0, -1.5), (2.6, 1.6)] {
                    var w = Path()
                    w.move(to: CGPoint(x: 50 + side * 22.5, y: 64.5 + dy))
                    w.addLine(to: CGPoint(x: 50 + side * 32.5, y: 64.5 + dy + spread))
                    g.stroke(w, with: .color(outline.opacity(0.65)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                }
            }
        case .bunny, .hamster:
            g.fill(Path(ellipseIn: CGRect(x: 48.2, y: 62.3, width: 3.6, height: 2.6)), with: .color(blush))
        case .fox:
            g.fill(Path(ellipseIn: CGRect(x: 48, y: 62.4, width: 4, height: 3)), with: .color(ink))
        case .panda:
            g.fill(Path(ellipseIn: CGRect(x: 47.6, y: 62.4, width: 4.8, height: 3.2)), with: .color(ink))
        default:
            break
        }
    }

    private func drawEyes(_ g: inout GraphicsContext, _ eyes: [CGPoint]) {
        let gaze = CGPoint(x: sin(t * 0.45) * 1.1 + (sin(t * 0.13) > 0.7 ? 1.2 : 0), y: cos(t * 0.31) * 0.5)
        let blinking = (t + 0.7).truncatingRemainder(dividingBy: 3.9) < 0.14
        let sclera = species == .panda || species == .frog
        // Closed-eye arcs on a dark panda patch need to be light.
        let lineInk = species == .panda && look.color.luminance < 0.55 ? Color.white : ink
        let small = species == .axolotl

        switch mood {
        case .happy, .celebrate:
            for e in eyes {
                var arc = Path()
                arc.move(to: CGPoint(x: e.x - 4.4, y: e.y + 1.9))
                arc.addQuadCurve(to: CGPoint(x: e.x + 4.4, y: e.y + 1.9), control: CGPoint(x: e.x, y: e.y - 5))
                g.stroke(arc, with: .color(lineInk), style: StrokeStyle(lineWidth: 2.7, lineCap: .round))
            }
        case .sleepy:
            for e in eyes {
                var arc = Path()
                arc.move(to: CGPoint(x: e.x - 4.4, y: e.y))
                arc.addQuadCurve(to: CGPoint(x: e.x + 4.4, y: e.y), control: CGPoint(x: e.x, y: e.y + 4))
                g.stroke(arc, with: .color(lineInk), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        default:
            var w: Double = mood == .alert ? 9.4 : (mood == .sad ? 7.8 : 8.6)
            var h: Double = mood == .alert ? 11.4 : (mood == .sad ? 9.2 : 10.4)
            if small { w *= 0.82; h *= 0.82 }
            if sclera { w *= 0.74; h *= 0.74 }
            if blinking { h *= 0.12 }
            for e in eyes {
                if sclera {
                    let white = CGRect(x: e.x - 5.6, y: e.y - 6.2, width: 11.2, height: blinking ? 2 : 12.4)
                    g.fill(Path(ellipseIn: white), with: .color(.white))
                    g.stroke(Path(ellipseIn: white), with: .color(outline.opacity(0.35)), lineWidth: 0.8)
                }
                let c = CGPoint(x: e.x + gaze.x * (sclera ? 0.8 : 1), y: e.y + gaze.y)
                g.fill(Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)), with: .color(ink))
                if !blinking {
                    let big = w * 0.24
                    g.fill(Path(ellipseIn: CGRect(x: c.x + w * 0.12, y: c.y - h * 0.36, width: big * 2, height: big * 2)),
                           with: .color(.white.opacity(0.95)))
                    g.fill(Path(ellipseIn: CGRect(x: c.x - w * 0.32, y: c.y + h * 0.12, width: big, height: big)),
                           with: .color(.white.opacity(0.75)))
                }
            }
            if mood == .sad || mood == .exercise {
                let sad = mood == .sad
                var brows = Path()
                for (i, e) in eyes.enumerated() {
                    let side: Double = i == 0 ? -1 : 1
                    let outer = CGPoint(x: e.x + side * 4.5, y: e.y - (sad ? 7.2 : 9.8))
                    let inner = CGPoint(x: e.x - side * 3.5, y: e.y - (sad ? 9.8 : 7.2))
                    brows.move(to: outer)
                    brows.addLine(to: inner)
                }
                g.stroke(brows, with: .color(lineInk), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    private func drawMouth(_ g: inout GraphicsContext) {
        if species == .chick || species == .penguin {
            drawBeak(&g)
            return
        }
        let y = mouthY
        let wide = species == .frog || species == .axolotl
        let half: Double = wide ? 9 : 5.5

        switch mood {
        case .happy, .celebrate:
            var m = Path()
            m.move(to: CGPoint(x: 50 - half, y: y - 1.5))
            m.addQuadCurve(to: CGPoint(x: 50 + half, y: y - 1.5), control: CGPoint(x: 50, y: y + (wide ? 10 : 8.5)))
            m.closeSubpath()
            g.fill(m, with: .color(ink))
            var tongue = g
            tongue.clip(to: m)
            tongue.fill(Path(ellipseIn: CGRect(x: 50 - 3.5, y: y + 1.8, width: 7, height: 5)),
                        with: .color(Color(.sRGB, red: 1, green: 0.45, blue: 0.52)))
        case .alert:
            g.fill(Path(ellipseIn: CGRect(x: 47.2, y: y - 2.2, width: 5.6, height: 6.4)), with: .color(ink))
        case .sleepy:
            g.fill(Path(ellipseIn: CGRect(x: 48.4, y: y - 0.6, width: 3.2, height: 3.2)), with: .color(ink.opacity(0.85)))
        case .sad:
            var m = Path()
            m.move(to: CGPoint(x: 50 - half * 0.82, y: y + 2.4))
            m.addQuadCurve(to: CGPoint(x: 50 + half * 0.82, y: y + 2.4), control: CGPoint(x: 50, y: y - 2))
            g.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .exercise:
            let puff = (sin(t * 3.4) + 1) / 2
            let w = 4 + puff * 1.6, h = 3 + puff * 2
            g.fill(Path(ellipseIn: CGRect(x: 50 - w / 2, y: y - h / 2 + 0.5, width: w, height: h)), with: .color(ink))
        case .idle:
            if species == .kitty || species == .bunny || species == .hamster {
                // A little "w" mouth.
                var m = Path()
                m.move(to: CGPoint(x: 45.8, y: y - 1.2))
                m.addQuadCurve(to: CGPoint(x: 50, y: y - 0.8), control: CGPoint(x: 47.8, y: y + 2.8))
                m.addQuadCurve(to: CGPoint(x: 54.2, y: y - 1.2), control: CGPoint(x: 52.2, y: y + 2.8))
                g.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                if species != .kitty {
                    let teeth = CGRect(x: 48.5, y: y + 0.4, width: 3, height: 2.8)
                    g.fill(Path(roundedRect: teeth, cornerRadius: 0.8), with: .color(.white))
                    g.stroke(Path(roundedRect: teeth, cornerRadius: 0.8), with: .color(ink.opacity(0.6)), lineWidth: 0.7)
                }
            } else {
                var m = Path()
                m.move(to: CGPoint(x: 50 - half * 0.82, y: y - 0.5))
                m.addQuadCurve(to: CGPoint(x: 50 + half * 0.82, y: y - 0.5), control: CGPoint(x: 50, y: y + (wide ? 5.5 : 4.5)))
                g.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
        }
    }

    private func drawBeak(_ g: inout GraphicsContext) {
        let open = mood == .happy || mood == .celebrate || mood == .alert || mood == .exercise
        let y = 63.5
        let gap: Double = open ? 2.6 : 0
        var upper = Path()
        upper.move(to: CGPoint(x: 45.8, y: y))
        upper.addQuadCurve(to: CGPoint(x: 54.2, y: y), control: CGPoint(x: 50, y: y - 4.6))
        upper.addQuadCurve(to: CGPoint(x: 45.8, y: y), control: CGPoint(x: 50, y: y + 1.6))
        var lower = Path()
        lower.move(to: CGPoint(x: 46.8, y: y + gap))
        lower.addQuadCurve(to: CGPoint(x: 53.2, y: y + gap), control: CGPoint(x: 50, y: y + gap + 4.2))
        lower.closeSubpath()
        if open {
            g.fill(Path(ellipseIn: CGRect(x: 47, y: y - 0.5, width: 6, height: gap + 2.5)), with: .color(ink))
        }
        let edge = beakRGB.darker(0.35).color
        g.fill(lower, with: .color(beakRGB.darker(0.08).color))
        g.stroke(lower, with: .color(edge), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        g.fill(upper, with: .color(beakRGB.color))
        g.stroke(upper, with: .color(edge), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
    }

    // MARK: Gear

    private func drawNeckGear(_ g: inout GraphicsContext) {
        switch look.neck {
        case .none:
            break
        case .towel:
            // A white gym towel with a coral stripe reads on every palette.
            let towel = RGB(r: 0.98, g: 0.98, b: 1.0)
            let edge = RGB(r: 0.55, g: 0.58, b: 0.7)
            let stripe = Color(.sRGB, red: 1, green: 0.45, blue: 0.5)
            var band = Path()
            band.move(to: CGPoint(x: 23, y: 69))
            band.addQuadCurve(to: CGPoint(x: 77, y: 69), control: CGPoint(x: 50, y: 83))
            var wrap = g
            wrap.clip(to: bodyPath)
            wrap.stroke(band, with: .color(edge.color), style: StrokeStyle(lineWidth: 8.4, lineCap: .round))
            wrap.stroke(band, with: .color(towel.color), style: StrokeStyle(lineWidth: 6.6, lineCap: .round))
            wrap.stroke(band, with: .color(stripe), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            var end = g
            end.translateBy(x: 31, y: 72)
            end.rotate(by: .degrees(9 + sin(t * 2) * 2))
            let shape = Path(roundedRect: CGRect(x: -4, y: 0, width: 8, height: 15.5), cornerRadius: 2)
            end.fill(shape, with: .color(towel.color))
            end.stroke(shape, with: .color(edge.color), lineWidth: 1.1)
            for y in [9.5, 12] {
                end.fill(Path(CGRect(x: -4, y: y, width: 8, height: 1.3)), with: .color(stripe))
            }
        case .whistle:
            var cord = Path()
            cord.move(to: CGPoint(x: 31, y: 68.5))
            cord.addQuadCurve(to: CGPoint(x: 50, y: 79), control: CGPoint(x: 40, y: 77))
            cord.addQuadCurve(to: CGPoint(x: 69, y: 68.5), control: CGPoint(x: 60, y: 77))
            var clipped = g
            clipped.clip(to: bodyPath)
            clipped.stroke(cord, with: .color(Color(.sRGB, red: 0.95, green: 0.3, blue: 0.36)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            var w = g
            w.translateBy(x: 50, y: 82)
            w.rotate(by: .degrees(sin(t * 2.2) * 6))
            w.scaleBy(x: 1.45, y: 1.45)
            let silver = Gradient(colors: [Color(white: 0.97), Color(white: 0.7)])
            let barrel = Path(roundedRect: CGRect(x: -4.6, y: -2.8, width: 8.4, height: 5.6), cornerRadius: 2.8)
            let mouthpiece = Path(roundedRect: CGRect(x: 2.4, y: -2.8, width: 4.8, height: 2.6), cornerRadius: 1)
            for part in [mouthpiece, barrel] {
                w.fill(part, with: .linearGradient(silver, startPoint: CGPoint(x: 0, y: -3), endPoint: CGPoint(x: 0, y: 3)))
                w.stroke(part, with: .color(Color(white: 0.45)), lineWidth: 0.9)
            }
            w.fill(Path(ellipseIn: CGRect(x: -2.6, y: -1.3, width: 2.6, height: 2.6)), with: .color(Color(white: 0.35)))
        case .medal:
            var ribbon = g
            ribbon.clip(to: bodyPath)
            var left = Path()
            left.move(to: CGPoint(x: 36, y: 67))
            left.addLine(to: CGPoint(x: 48.6, y: 79.5))
            var right = Path()
            right.move(to: CGPoint(x: 64, y: 67))
            right.addLine(to: CGPoint(x: 51.4, y: 79.5))
            ribbon.stroke(left, with: .color(Color(.sRGB, red: 0.32, green: 0.52, blue: 1.0)), style: StrokeStyle(lineWidth: 4.2, lineCap: .butt))
            ribbon.stroke(right, with: .color(Color(.sRGB, red: 1.0, green: 0.42, blue: 0.47)), style: StrokeStyle(lineWidth: 4.2, lineCap: .butt))
            let disc = CGRect(x: 44.2, y: 77.4, width: 11.6, height: 11.6)
            g.fill(Path(ellipseIn: disc), with: .linearGradient(Gradient(colors: [gold.lighter(0.4).color, gold.color, gold.darker(0.15).color]),
                                                                  startPoint: CGPoint(x: 46, y: 78), endPoint: CGPoint(x: 54, y: 89)))
            g.stroke(Path(ellipseIn: disc), with: .color(gold.darker(0.45).color), lineWidth: 1.2)
            g.fill(star(center: CGPoint(x: 50, y: 83.3), radius: 3.1), with: .color(gold.lighter(0.55).color))
        }
    }

    private func star(center: CGPoint, radius: Double) -> Path {
        var p = Path()
        for i in 0..<10 {
            let r = i % 2 == 0 ? radius : radius * 0.45
            let a = Double(i) * .pi / 5 - .pi / 2
            let point = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    private func drawHeadGear(_ g: inout GraphicsContext, back: Bool) {
        var h = g
        if back {
            // Seen from behind everything flips left to right.
            h.translateBy(x: 100, y: 0)
            h.scaleBy(x: -1, y: 1)
        }
        switch look.head {
        case .none:
            break
        case .sweatband:
            let red = Color(.sRGB, red: 1.0, green: 0.36, blue: 0.4)
            let y: Double = species == .frog ? 44 : 40.5
            var band = h
            band.clip(to: bodyPath)
            band.fill(Path(CGRect(x: 10, y: y, width: 80, height: 7)), with: .color(red))
            band.fill(Path(CGRect(x: 10, y: y + 2.8, width: 80, height: 1.5)), with: .color(.white.opacity(0.9)))
            for (i, angle) in [18.0, 52.0].enumerated() {
                var tail = h
                tail.translateBy(x: 79.5, y: y + 3.5)
                tail.rotate(by: .degrees(angle + sin(t * 3 + Double(i)) * 6))
                tail.fill(Path(roundedRect: CGRect(x: 0, y: -2, width: 10, height: 4), cornerRadius: 2), with: .color(red))
            }
        case .cap:
            var cap = h
            if species == .frog {
                cap.translateBy(x: 50, y: 33)
                cap.scaleBy(x: 0.55, y: 0.55)
                cap.translateBy(x: -50, y: -40)
            }
            let blue = RGB(r: 0.3, g: 0.46, b: 0.98)
            var brim = Path()
            brim.move(to: CGPoint(x: 62, y: 37.5))
            brim.addQuadCurve(to: CGPoint(x: 86, y: 40), control: CGPoint(x: 77, y: 33))
            brim.addLine(to: CGPoint(x: 85.5, y: 42.6))
            brim.addQuadCurve(to: CGPoint(x: 62, y: 41.8), control: CGPoint(x: 75, y: 44.8))
            brim.closeSubpath()
            cap.fill(brim, with: .color(blue.darker(0.14).color))
            cap.stroke(brim, with: .color(blue.darker(0.5).color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            var dome = Path()
            dome.move(to: CGPoint(x: 30, y: 41))
            dome.addCurve(to: CGPoint(x: 70, y: 41), control1: CGPoint(x: 31, y: 20.5), control2: CGPoint(x: 69, y: 20.5))
            dome.closeSubpath()
            cap.fill(dome, with: .linearGradient(Gradient(colors: [blue.lighter(0.25).color, blue.color]),
                                                 startPoint: CGPoint(x: 50, y: 24), endPoint: CGPoint(x: 50, y: 41)))
            var seam = Path()
            seam.move(to: CGPoint(x: 50, y: 26))
            seam.addQuadCurve(to: CGPoint(x: 50, y: 41), control: CGPoint(x: 52, y: 33))
            cap.stroke(seam, with: .color(blue.darker(0.4).color.opacity(0.5)), lineWidth: 0.9)
            cap.fill(Path(CGRect(x: 30, y: 37.6, width: 40, height: 2.2)), with: .color(.white.opacity(0.85)))
            cap.fill(star(center: CGPoint(x: 42, y: 32), radius: 3), with: .color(.white.opacity(0.95)))
            cap.stroke(dome, with: .color(blue.darker(0.5).color), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
            cap.fill(Path(ellipseIn: CGRect(x: 48.2, y: 23.4, width: 3.6, height: 3.6)), with: .color(blue.darker(0.25).color))
        case .headphones:
            let cups = RGB(r: 1.0, g: 0.45, b: 0.5)
            var band = Path()
            band.move(to: CGPoint(x: 21.5, y: 52))
            band.addCurve(to: CGPoint(x: 78.5, y: 52), control1: CGPoint(x: 20, y: 17), control2: CGPoint(x: 80, y: 17))
            h.stroke(band, with: .color(Color(.sRGB, red: 0.24, green: 0.25, blue: 0.33)), style: StrokeStyle(lineWidth: 4.4, lineCap: .round))
            h.stroke(band, with: .color(Color(white: 0.62)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            for side in [-1.0, 1.0] {
                let cx = 50 + side * 30.5
                let cup = Path(roundedRect: CGRect(x: cx - 5.2, y: 46.5, width: 10.4, height: 17), cornerRadius: 4.8)
                h.fill(cup, with: .linearGradient(Gradient(colors: [cups.lighter(0.2).color, cups.color]),
                                                  startPoint: CGPoint(x: cx, y: 46), endPoint: CGPoint(x: cx, y: 64)))
                h.stroke(cup, with: .color(cups.darker(0.45).color), lineWidth: 1.4)
                h.fill(Path(roundedRect: CGRect(x: cx - 1.4 - side * 0.6, y: 49.5, width: 2.8, height: 9), cornerRadius: 1.4),
                       with: .color(.white.opacity(0.45)))
            }
        case .shades:
            guard !back else { break }
            let eyes = eyeCenters
            let lens = Gradient(colors: [Color(.sRGB, red: 0.44, green: 0.27, blue: 0.88), Color(.sRGB, red: 0.15, green: 0.76, blue: 0.86)])
            let frame = Color(.sRGB, red: 0.12, green: 0.11, blue: 0.2)
            var temple = Path()
            temple.move(to: CGPoint(x: eyes[0].x - 9.5, y: eyes[0].y - 2.5))
            temple.addLine(to: CGPoint(x: max(19, eyes[0].x - 17), y: eyes[0].y - 4))
            temple.move(to: CGPoint(x: eyes[1].x + 9.5, y: eyes[1].y - 2.5))
            temple.addLine(to: CGPoint(x: min(81, eyes[1].x + 17), y: eyes[1].y - 4))
            h.stroke(temple, with: .color(frame), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            for e in eyes {
                let r = CGRect(x: e.x - 9.5, y: e.y - 5.6, width: 19, height: 11.2)
                h.fill(Path(roundedRect: r, cornerRadius: 5), with: .linearGradient(lens, startPoint: CGPoint(x: r.minX, y: r.minY),
                                                                                    endPoint: CGPoint(x: r.maxX, y: r.maxY)))
                h.stroke(Path(roundedRect: r, cornerRadius: 5), with: .color(frame), lineWidth: 1.4)
                var glare = Path()
                glare.move(to: CGPoint(x: r.minX + 4, y: r.maxY - 3))
                glare.addLine(to: CGPoint(x: r.minX + 8, y: r.minY + 2.6))
                h.stroke(glare, with: .color(.white.opacity(0.65)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: eyes[0].x + 9.5, y: eyes[0].y - 2))
            bridge.addQuadCurve(to: CGPoint(x: eyes[1].x - 9.5, y: eyes[1].y - 2),
                                control: CGPoint(x: 50, y: eyes[0].y - 5))
            h.stroke(bridge, with: .color(frame), lineWidth: 2)
        case .crown:
            var crown = h
            if species == .frog {
                crown.translateBy(x: 50, y: 37)
                crown.scaleBy(x: 0.7, y: 0.7)
                crown.translateBy(x: -50, y: -37.5)
            }
            var shape = Path()
            shape.move(to: CGPoint(x: 38, y: 37.5))
            shape.addLine(to: CGPoint(x: 37.5, y: 25))
            shape.addLine(to: CGPoint(x: 44, y: 30.5))
            shape.addLine(to: CGPoint(x: 50, y: 21))
            shape.addLine(to: CGPoint(x: 56, y: 30.5))
            shape.addLine(to: CGPoint(x: 62.5, y: 25))
            shape.addLine(to: CGPoint(x: 62, y: 37.5))
            shape.closeSubpath()
            crown.fill(shape, with: .linearGradient(Gradient(colors: [gold.lighter(0.35).color, gold.color]),
                                                    startPoint: CGPoint(x: 50, y: 21), endPoint: CGPoint(x: 50, y: 37.5)))
            crown.stroke(shape, with: .color(gold.darker(0.4).color), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
            let jewels: [(Double, Color)] = [(44, Color(.sRGB, red: 0.95, green: 0.3, blue: 0.4)),
                                             (50, Color(.sRGB, red: 0.3, green: 0.6, blue: 1.0)),
                                             (56, Color(.sRGB, red: 0.95, green: 0.3, blue: 0.4))]
            for (x, color) in jewels {
                crown.fill(Path(ellipseIn: CGRect(x: x - 1.9, y: 31.6, width: 3.8, height: 3.8)), with: .color(color))
            }
        }
    }

    private func drawHeldGear(_ g: inout GraphicsContext, pose p: Pose) {
        switch look.hands {
        case .none:
            break
        case .dumbbells:
            held(&g, left: true, angle: p.armL, upright: false) { dumbbell(&$0) }
            held(&g, left: false, angle: p.armR, upright: false) { dumbbell(&$0) }
        case .bottle:
            held(&g, left: false, angle: p.armR, upright: true) { bottle(&$0) }
        case .kettlebell:
            held(&g, left: false, angle: p.armR, upright: true) { kettlebell(&$0) }
        case .trophy:
            held(&g, left: false, angle: p.armR, upright: true) { trophy(&$0) }
        }
    }

    /// Positions a held item at the end of an arm. Upright items stay (mostly) level.
    private func held(_ g: inout GraphicsContext, left: Bool, angle: Double, upright: Bool,
                      _ draw: (inout GraphicsContext) -> Void) {
        var h = g
        h.translateBy(x: left ? 23 : 77, y: 63)
        let rotation = left ? angle : -angle
        h.rotate(by: .degrees(rotation))
        h.translateBy(x: 0, y: 14)
        if upright { h.rotate(by: .degrees(-rotation * 0.85)) }
        draw(&h)
    }

    private func dumbbell(_ g: inout GraphicsContext) {
        let plate = RGB(r: 0.36, g: 0.49, b: 0.98)
        g.fill(Path(roundedRect: CGRect(x: -7.5, y: -1.15, width: 15, height: 2.3), cornerRadius: 1.15), with: .color(Color(white: 0.62)))
        for x in [-9.6, 6.2] {
            let r = CGRect(x: x, y: -4.8, width: 3.4, height: 9.6)
            g.fill(Path(roundedRect: r, cornerRadius: 1.5), with: .color(plate.color))
            g.stroke(Path(roundedRect: r, cornerRadius: 1.5), with: .color(plate.darker(0.45).color), lineWidth: 1)
        }
        for x in [-6.4, 4.2] {
            let r = CGRect(x: x, y: -3.4, width: 2.2, height: 6.8)
            g.fill(Path(roundedRect: r, cornerRadius: 1), with: .color(plate.lighter(0.25).color))
            g.stroke(Path(roundedRect: r, cornerRadius: 1), with: .color(plate.darker(0.45).color), lineWidth: 0.8)
        }
    }

    private func bottle(_ g: inout GraphicsContext) {
        let water = RGB(r: 0.55, g: 0.8, b: 1.0)
        let body = Path(roundedRect: CGRect(x: -3.8, y: -8, width: 7.6, height: 15.5), cornerRadius: 3)
        g.fill(body, with: .color(water.color))
        g.fill(Path(CGRect(x: -3.8, y: -1.2, width: 7.6, height: 3.2)), with: .color(.white.opacity(0.7)))
        g.fill(Path(roundedRect: CGRect(x: -2.3, y: -5.5, width: 1.4, height: 10), cornerRadius: 0.7), with: .color(.white.opacity(0.5)))
        g.stroke(body, with: .color(water.darker(0.45).color), lineWidth: 1.1)
        let cap = Path(roundedRect: CGRect(x: -2.5, y: -11.2, width: 5, height: 3.8), cornerRadius: 1.2)
        g.fill(cap, with: .color(Color(.sRGB, red: 1, green: 0.5, blue: 0.52)))
        g.stroke(cap, with: .color(Color(.sRGB, red: 0.6, green: 0.2, blue: 0.25)), lineWidth: 0.9)
    }

    private func kettlebell(_ g: inout GraphicsContext) {
        let iron = RGB(r: 0.98, g: 0.55, b: 0.3)
        var handle = Path()
        handle.move(to: CGPoint(x: -4.8, y: 4))
        handle.addCurve(to: CGPoint(x: 4.8, y: 4), control1: CGPoint(x: -5.4, y: -5.5), control2: CGPoint(x: 5.4, y: -5.5))
        g.stroke(handle, with: .color(Color(white: 0.3)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        g.stroke(handle, with: .color(Color(white: 0.62)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        let ball = Path(ellipseIn: CGRect(x: -7, y: 1.5, width: 14, height: 13))
        g.fill(ball, with: .linearGradient(Gradient(colors: [iron.lighter(0.3).color, iron.darker(0.2).color]),
                                           startPoint: CGPoint(x: -4, y: 2), endPoint: CGPoint(x: 4, y: 14)))
        g.stroke(ball, with: .color(iron.darker(0.5).color), lineWidth: 1.1)
        g.fill(Path(ellipseIn: CGRect(x: -4, y: 3.8, width: 3.6, height: 2.4)), with: .color(.white.opacity(0.45)))
    }

    private func trophy(_ g: inout GraphicsContext) {
        let shading = GraphicsContext.Shading.linearGradient(Gradient(colors: [gold.lighter(0.45).color, gold.color, gold.darker(0.2).color]),
                                                             startPoint: CGPoint(x: -6, y: -12), endPoint: CGPoint(x: 6, y: 6))
        let edge = gold.darker(0.45).color
        for side in [-1.0, 1.0] {
            let handle = Path(ellipseIn: CGRect(x: side < 0 ? -9.4 : 4.6, y: -10.5, width: 4.8, height: 5.6))
            g.stroke(handle, with: .color(edge), lineWidth: 2.6)
            g.stroke(handle, with: .color(gold.color), lineWidth: 1.4)
        }
        var bowl = Path()
        bowl.move(to: CGPoint(x: -6.2, y: -12))
        bowl.addLine(to: CGPoint(x: 6.2, y: -12))
        bowl.addQuadCurve(to: CGPoint(x: 0, y: -1.5), control: CGPoint(x: 6.4, y: -2))
        bowl.addQuadCurve(to: CGPoint(x: -6.2, y: -12), control: CGPoint(x: -6.4, y: -2))
        bowl.closeSubpath()
        let stem = Path(CGRect(x: -1.3, y: -2, width: 2.6, height: 4.4))
        let base = Path(roundedRect: CGRect(x: -4.8, y: 2.2, width: 9.6, height: 3), cornerRadius: 1)
        for part in [stem, base, bowl] {
            g.fill(part, with: shading)
            g.stroke(part, with: .color(edge), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
        }
        g.fill(star(center: CGPoint(x: 0, y: -7.6), radius: 2.3), with: .color(gold.lighter(0.6).color))
    }

    // MARK: Effects

    private func drawEffects(_ g: inout GraphicsContext, pose p: Pose, back: Bool) {
        switch mood {
        case .sleepy:
            for i in 0..<3 {
                let phase = (t * 0.32 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                var z = g
                z.opacity = sin(phase * .pi)
                z.draw(Text("z").font(.system(size: 6 + phase * 7, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(white: 0.55)),
                       at: CGPoint(x: 75 + phase * 13 + sin(phase * 6) * 2, y: 35 - phase * 26))
            }
        case .happy, .celebrate:
            for i in 0..<3 {
                let phase = (t * 0.45 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                let x = [17.0, 83.0, 72.0][i] + sin(phase * 5 + Double(i)) * 3
                var heart = g
                heart.opacity = sin(phase * .pi)
                let sparkle = mood == .celebrate && i == 1
                heart.draw(Text(sparkle ? "✦" : "♥").font(.system(size: 7 + phase * 4, weight: .bold))
                    .foregroundColor(sparkle ? yellow : Color(.sRGB, red: 1, green: 0.45, blue: 0.6)),
                           at: CGPoint(x: x, y: 52 - phase * 42))
            }
        case .alert:
            let pulse = 1 + sin(t * 8) * 0.08
            var bubble = g
            bubble.translateBy(x: 84, y: 23 - p.lift * 0.6)
            bubble.scaleBy(x: pulse, y: pulse)
            bubble.fill(Path(ellipseIn: CGRect(x: -8.5, y: -8.5, width: 17, height: 17)),
                        with: .color(Color(.sRGB, red: 1, green: 0.42, blue: 0.42)))
            bubble.draw(Text("!").font(.system(size: 13, weight: .black, design: .rounded)).foregroundColor(.white),
                        at: CGPoint(x: 0, y: 0.3))
        case .exercise:
            let phase = (t * 0.8).truncatingRemainder(dividingBy: 1)
            var d = g
            d.opacity = 1 - phase
            d.translateBy(x: back ? 20 : 80, y: 40 + phase * 10)
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: -4.5))
            drop.addQuadCurve(to: CGPoint(x: 0, y: 4), control: CGPoint(x: 5.5, y: 3))
            drop.addQuadCurve(to: CGPoint(x: 0, y: -4.5), control: CGPoint(x: -5.5, y: 3))
            d.fill(drop, with: .color(Color(.sRGB, red: 0.45, green: 0.75, blue: 1)))
        case .sad:
            let phase = (t * 0.45).truncatingRemainder(dividingBy: 1)
            guard phase < 0.7, look.head != .shades, !back else { break }
            let eye = eyeCenters[0]
            var tear = g
            tear.opacity = 1 - phase / 0.7
            tear.translateBy(x: eye.x - 2.5 + p.tilt * 0.3, y: eye.y + 4 + phase * 14)
            tear.fill(Path(ellipseIn: CGRect(x: -1.6, y: -2.2, width: 3.2, height: 4.4)),
                      with: .color(Color(.sRGB, red: 0.5, green: 0.78, blue: 1)))
        case .idle:
            break
        }
    }
}
