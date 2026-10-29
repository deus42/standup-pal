import SwiftUI

enum PetMood: String, CaseIterable, Identifiable {
    case idle, happy, alert, sleepy, sad, exercise, celebrate
    var id: String { rawValue }

    var label: String {
        switch self {
        case .idle: return "Chilling"
        case .happy: return "Happy"
        case .alert: return "Calling you"
        case .sleepy: return "Sleepy"
        case .sad: return "Sad"
        case .exercise: return "Working out"
        case .celebrate: return "Celebrating"
        }
    }
}

struct PetLook: Equatable {
    var species: PetSpecies
    var color: RGB
    var accessory: PetAccessory

    static func from(_ s: AppSettings) -> PetLook {
        PetLook(species: s.petSpecies, color: RGB(hex: s.petColorHex), accessory: s.petAccessory)
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

    private struct Pose {
        var lift = 0.0
        var sx = 1.0
        var sy = 1.0
        var tilt = 0.0
        var armL = 22.0
        var armR = 22.0
    }

    private let ink = Color(.sRGB, red: 0.17, green: 0.14, blue: 0.25)
    private let blush = Color(.sRGB, red: 1.0, green: 0.52, blue: 0.62)
    private let yellow = Color(.sRGB, red: 1.0, green: 0.84, blue: 0.4)
    private var outline: Color { look.color.darker(0.5).color }

    private let bodyRect = CGRect(x: 18, y: 34, width: 64, height: 57)
    private var bodyPath: Path { Path(roundedRect: bodyRect, cornerRadius: 28, style: .continuous) }

    // MARK: Entry

    func draw(_ context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height) / 100 * zoom
        var ctx = context
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.scaleBy(x: unit, y: unit)
        ctx.translateBy(x: -50, y: -(50 + (zoom - 1) * 45))

        let p = pose()

        let liftFactor = min(1, p.lift / 30)
        let shadowWidth = 50 * (1 - liftFactor * 0.5)
        ctx.fill(Path(ellipseIn: CGRect(x: 50 - shadowWidth / 2, y: 90, width: shadowWidth, height: 6)),
                 with: .color(.black.opacity(0.14 * (1 - liftFactor * 0.6))))

        var body = ctx
        body.translateBy(x: 50, y: 91 - p.lift)
        body.rotate(by: .degrees(p.tilt))
        body.scaleBy(x: p.sx, y: p.sy)
        body.translateBy(x: -50, y: -91)

        drawBackLayer(&body, pose: p)
        drawBody(&body)
        drawFace(&body)
        drawAccessory(&body)
        if effects { drawEffects(&ctx, pose: p) }
    }

    private func pose() -> Pose {
        var p = Pose()
        switch mood {
        case .idle:
            let b = sin(t * 2.0)
            p.sy = 1 + b * 0.022
            p.sx = 1 - b * 0.014
            p.tilt = sin(t * 0.8) * 2
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
        case .celebrate:
            let phase = (t * 2.0).truncatingRemainder(dividingBy: 1)
            let hop = sin(phase * .pi)
            p.lift = hop * 11
            p.sy = 1 + hop * 0.06
            p.sx = 1 - hop * 0.04
            p.armL = 150 + sin(t * 12) * 18
            p.armR = 150 + sin(t * 12 + 1.5) * 18
            p.tilt = sin(t * 4) * 4
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
        return p
    }

    // MARK: Layers

    private func drawBackLayer(_ g: inout GraphicsContext, pose p: Pose) {
        let fill = look.color.color
        let innerEar = blush.opacity(0.55)

        switch look.species {
        case .blob:
            if ![.sprout, .partyHat, .crown].contains(look.accessory) {
                let sway = sin(t * 2.3) * (mood == .alert ? 5 : 2.5)
                var stem = Path()
                stem.move(to: CGPoint(x: 50, y: 36))
                stem.addQuadCurve(to: CGPoint(x: 52 + sway, y: 19.5), control: CGPoint(x: 47.5, y: 27))
                g.stroke(stem, with: .color(outline), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                let ball = CGRect(x: 52 + sway - 4.6, y: 14.6, width: 9.2, height: 9.2)
                g.fill(Path(ellipseIn: ball), with: .color(yellow))
                g.stroke(Path(ellipseIn: ball), with: .color(outline), lineWidth: 1.7)
            }
        case .kitty:
            for side in [-1.0, 1.0] {
                let twitch = side > 0 ? max(0, sin(t * 1.7) - 0.85) * 45 : 0
                var e = g
                e.translateBy(x: 50 + side * 20, y: 42)
                e.rotate(by: .degrees(side * (14 + twitch)))
                var ear = Path()
                ear.move(to: CGPoint(x: -10.5, y: 5))
                ear.addLine(to: CGPoint(x: 0, y: -19))
                ear.addLine(to: CGPoint(x: 10.5, y: 5))
                ear.closeSubpath()
                e.fill(ear, with: .color(fill))
                e.stroke(ear, with: .color(outline), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
                var inner = Path()
                inner.move(to: CGPoint(x: -5, y: 1))
                inner.addLine(to: CGPoint(x: 0, y: -11))
                inner.addLine(to: CGPoint(x: 5, y: 1))
                inner.closeSubpath()
                e.fill(inner, with: .color(innerEar))
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
        case .bear:
            for side in [-1.0, 1.0] {
                let center = CGPoint(x: 50 + side * 22, y: 39)
                let ear = CGRect(x: center.x - 9.5, y: center.y - 9.5, width: 19, height: 19)
                g.fill(Path(ellipseIn: ear), with: .color(fill))
                g.stroke(Path(ellipseIn: ear), with: .color(outline), lineWidth: 2.2)
                g.fill(Path(ellipseIn: ear.insetBy(dx: 5, dy: 5)), with: .color(look.color.darker(0.18).color))
            }
        }

        arm(&g, pivot: CGPoint(x: 23, y: 63), angle: p.armL, left: true)
        arm(&g, pivot: CGPoint(x: 77, y: 63), angle: p.armR, left: false)

        for x in [33.5, 54.5] {
            let foot = CGRect(x: x, y: 85.5, width: 12, height: 8)
            g.fill(Path(ellipseIn: foot), with: .color(look.color.darker(0.22).color))
            g.stroke(Path(ellipseIn: foot), with: .color(outline), lineWidth: 1.7)
        }
    }

    private func arm(_ g: inout GraphicsContext, pivot: CGPoint, angle: Double, left: Bool) {
        var a = g
        a.translateBy(x: pivot.x, y: pivot.y)
        a.rotate(by: .degrees(left ? angle : -angle))
        let shape = Path(roundedRect: CGRect(x: -4.2, y: -3, width: 8.4, height: 18), cornerRadius: 4.2)
        a.fill(shape, with: .color(look.color.darker(0.06).color))
        a.stroke(shape, with: .color(outline), lineWidth: 1.7)
    }

    private func drawBody(_ g: inout GraphicsContext) {
        let path = bodyPath
        g.fill(path, with: .linearGradient(
            Gradient(colors: [look.color.lighter(0.25).color, look.color.color, look.color.darker(0.08).color]),
            startPoint: CGPoint(x: 50, y: 34), endPoint: CGPoint(x: 50, y: 91)))

        var inside = g
        inside.clip(to: path)
        inside.fill(Path(ellipseIn: CGRect(x: 31, y: 67, width: 38, height: 30)), with: .color(.white.opacity(0.22)))

        g.stroke(path, with: .color(outline), lineWidth: 2.4)

        var shine = g
        shine.translateBy(x: 30.5, y: 43.5)
        shine.rotate(by: .degrees(-30))
        shine.fill(Path(ellipseIn: CGRect(x: -6, y: -2.8, width: 12, height: 5.6)), with: .color(.white.opacity(0.55)))
    }

    private func drawFace(_ g: inout GraphicsContext) {
        let eyes = [CGPoint(x: 39, y: 56), CGPoint(x: 61, y: 56)]
        let gaze = CGPoint(x: sin(t * 0.45) * 1.1 + (sin(t * 0.13) > 0.7 ? 1.2 : 0), y: cos(t * 0.31) * 0.5)
        let blinking = (t + 0.7).truncatingRemainder(dividingBy: 3.9) < 0.14

        let blushOpacity = (mood == .happy || mood == .celebrate) ? 0.65 : 0.42
        for x in [27.0, 64.0] {
            g.fill(Path(ellipseIn: CGRect(x: x, y: 61.5, width: 9, height: 5.5)), with: .color(blush.opacity(blushOpacity)))
        }

        if look.species == .bear {
            g.fill(Path(ellipseIn: CGRect(x: 40.5, y: 59, width: 19, height: 13.5)), with: .color(look.color.lighter(0.5).color))
            g.fill(Path(ellipseIn: CGRect(x: 47.2, y: 60, width: 5.6, height: 3.9)), with: .color(ink))
        }
        if look.species == .kitty {
            var nose = Path()
            nose.move(to: CGPoint(x: 48.3, y: 61.2))
            nose.addLine(to: CGPoint(x: 51.7, y: 61.2))
            nose.addLine(to: CGPoint(x: 50, y: 63.2))
            nose.closeSubpath()
            g.fill(nose, with: .color(blush))
            for side in [-1.0, 1.0] {
                for (dy, spread) in [(0.0, -1.5), (2.6, 1.6)] {
                    var w = Path()
                    w.move(to: CGPoint(x: 50 + side * 22.5, y: 63.5 + dy))
                    w.addLine(to: CGPoint(x: 50 + side * 32.5, y: 63.5 + dy + spread))
                    g.stroke(w, with: .color(outline.opacity(0.65)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                }
            }
        }

        if look.accessory != .shades {
            switch mood {
            case .happy, .celebrate:
                for e in eyes {
                    var arc = Path()
                    arc.move(to: CGPoint(x: e.x - 4.2, y: e.y + 1.8))
                    arc.addQuadCurve(to: CGPoint(x: e.x + 4.2, y: e.y + 1.8), control: CGPoint(x: e.x, y: e.y - 4.8))
                    g.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                }
            case .sleepy:
                for e in eyes {
                    var arc = Path()
                    arc.move(to: CGPoint(x: e.x - 4.2, y: e.y))
                    arc.addQuadCurve(to: CGPoint(x: e.x + 4.2, y: e.y), control: CGPoint(x: e.x, y: e.y + 3.8))
                    g.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
            default:
                let w: Double = mood == .alert ? 8.6 : (mood == .sad ? 6.8 : 7.6)
                let h: Double = (mood == .alert ? 10.6 : (mood == .sad ? 8.2 : 9.6)) * (blinking ? 0.12 : 1)
                for e in eyes {
                    let c = CGPoint(x: e.x + gaze.x, y: e.y + gaze.y)
                    g.fill(Path(ellipseIn: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)), with: .color(ink))
                    if !blinking {
                        g.fill(Path(ellipseIn: CGRect(x: c.x - w / 2 + w * 0.5, y: c.y - h / 2 + h * 0.13, width: 2.7, height: 2.7)),
                               with: .color(.white.opacity(0.95)))
                    }
                }
                if mood == .sad || mood == .exercise {
                    let sad = mood == .sad
                    var brows = Path()
                    brows.move(to: CGPoint(x: 34.5, y: sad ? 49.2 : 46.6))
                    brows.addLine(to: CGPoint(x: 42.5, y: sad ? 46.6 : 49.2))
                    brows.move(to: CGPoint(x: 57.5, y: sad ? 46.6 : 49.2))
                    brows.addLine(to: CGPoint(x: 65.5, y: sad ? 49.2 : 46.6))
                    g.stroke(brows, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
        }

        drawMouth(&g)
    }

    private func drawMouth(_ g: inout GraphicsContext) {
        let y = look.species == .bear ? 67.5 : (look.species == .kitty ? 66 : 65)
        switch mood {
        case .happy, .celebrate:
            var m = Path()
            m.move(to: CGPoint(x: 44.5, y: y - 1.5))
            m.addQuadCurve(to: CGPoint(x: 55.5, y: y - 1.5), control: CGPoint(x: 50, y: y + 8.5))
            m.closeSubpath()
            g.fill(m, with: .color(ink))
            var tongue = g
            tongue.clip(to: m)
            tongue.fill(Path(ellipseIn: CGRect(x: 46.5, y: y + 1.8, width: 7, height: 5)),
                        with: .color(Color(.sRGB, red: 1, green: 0.45, blue: 0.52)))
        case .alert:
            g.fill(Path(ellipseIn: CGRect(x: 47.2, y: y - 2.2, width: 5.6, height: 6.4)), with: .color(ink))
        case .sleepy:
            g.fill(Path(ellipseIn: CGRect(x: 48.4, y: y - 0.6, width: 3.2, height: 3.2)), with: .color(ink.opacity(0.85)))
        case .sad:
            var m = Path()
            m.move(to: CGPoint(x: 45.5, y: y + 2.4))
            m.addQuadCurve(to: CGPoint(x: 54.5, y: y + 2.4), control: CGPoint(x: 50, y: y - 2))
            g.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .exercise:
            let puff = (sin(t * 3.4) + 1) / 2
            let w = 4 + puff * 1.6, h = 3 + puff * 2
            g.fill(Path(ellipseIn: CGRect(x: 50 - w / 2, y: y - h / 2 + 0.5, width: w, height: h)), with: .color(ink))
        case .idle:
            var m = Path()
            m.move(to: CGPoint(x: 45.5, y: y - 0.5))
            m.addQuadCurve(to: CGPoint(x: 54.5, y: y - 0.5), control: CGPoint(x: 50, y: y + 4.5))
            g.stroke(m, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private func drawAccessory(_ g: inout GraphicsContext) {
        switch look.accessory {
        case .none:
            break
        case .sprout:
            let green = Color(.sRGB, red: 0.38, green: 0.74, blue: 0.4)
            var s = g
            s.translateBy(x: 50, y: 35.5)
            s.rotate(by: .degrees(sin(t * 1.8) * 5))
            var stem = Path()
            stem.move(to: .zero)
            stem.addQuadCurve(to: CGPoint(x: 0, y: -11), control: CGPoint(x: 2.2, y: -5))
            s.stroke(stem, with: .color(green.opacity(0.9)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            for (point, angle, w, h) in [(CGPoint(x: -5, y: -12), -32.0, 10.5, 5.6), (CGPoint(x: 5.5, y: -14), 26.0, 11.5, 6.2)] {
                var leaf = s
                leaf.translateBy(x: point.x, y: point.y)
                leaf.rotate(by: .degrees(angle))
                let shape = Path(ellipseIn: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                leaf.fill(shape, with: .color(green))
                leaf.stroke(shape, with: .color(Color(.sRGB, red: 0.2, green: 0.45, blue: 0.25)), lineWidth: 1.3)
            }
        case .sweatband:
            let red = Color(.sRGB, red: 1.0, green: 0.36, blue: 0.4)
            var band = g
            band.clip(to: bodyPath)
            band.fill(Path(CGRect(x: 10, y: 40.5, width: 80, height: 7)), with: .color(red))
            band.fill(Path(CGRect(x: 10, y: 43.3, width: 80, height: 1.5)), with: .color(.white.opacity(0.9)))
            for (i, angle) in [18.0, 52.0].enumerated() {
                var tail = g
                tail.translateBy(x: 79.5, y: 44)
                tail.rotate(by: .degrees(angle + sin(t * 3 + Double(i)) * 6))
                tail.fill(Path(roundedRect: CGRect(x: 0, y: -2, width: 10, height: 4), cornerRadius: 2), with: .color(red))
            }
        case .partyHat:
            let pink = Color(.sRGB, red: 1.0, green: 0.48, blue: 0.64)
            var hat = g
            hat.translateBy(x: 55, y: 37)
            hat.rotate(by: .degrees(12))
            var cone = Path()
            cone.move(to: CGPoint(x: -10.5, y: 0))
            cone.addLine(to: CGPoint(x: 0, y: -25))
            cone.addLine(to: CGPoint(x: 10.5, y: 0))
            cone.closeSubpath()
            hat.fill(cone, with: .color(pink))
            var stripes = hat
            stripes.clip(to: cone)
            for i in 0..<4 {
                stripes.fill(Path(CGRect(x: -12, y: -4.5 - Double(i) * 6.5, width: 24, height: 2.6)), with: .color(yellow))
            }
            hat.stroke(cone, with: .color(outline), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
            hat.fill(Path(ellipseIn: CGRect(x: -4, y: -29.5, width: 8, height: 8)), with: .color(yellow))
            hat.stroke(Path(ellipseIn: CGRect(x: -4, y: -29.5, width: 8, height: 8)), with: .color(outline), lineWidth: 1.3)
        case .shades:
            let lens = Color(.sRGB, red: 0.1, green: 0.1, blue: 0.16)
            for x in [31.0, 53.0] {
                let r = CGRect(x: x, y: 51, width: 16, height: 10.5)
                g.fill(Path(roundedRect: r, cornerRadius: 4.5), with: .color(lens))
                var glare = Path()
                glare.move(to: CGPoint(x: x + 4, y: 58.5))
                glare.addLine(to: CGPoint(x: x + 8, y: 53.2))
                g.stroke(glare, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            }
            var bridge = Path()
            bridge.move(to: CGPoint(x: 47, y: 54.5))
            bridge.addQuadCurve(to: CGPoint(x: 53, y: 54.5), control: CGPoint(x: 50, y: 52.3))
            g.stroke(bridge, with: .color(lens), lineWidth: 2)
        case .crown:
            let gold = RGB(r: 1.0, g: 0.79, b: 0.24)
            var crown = Path()
            crown.move(to: CGPoint(x: 38, y: 37.5))
            crown.addLine(to: CGPoint(x: 37.5, y: 25))
            crown.addLine(to: CGPoint(x: 44, y: 30.5))
            crown.addLine(to: CGPoint(x: 50, y: 21))
            crown.addLine(to: CGPoint(x: 56, y: 30.5))
            crown.addLine(to: CGPoint(x: 62.5, y: 25))
            crown.addLine(to: CGPoint(x: 62, y: 37.5))
            crown.closeSubpath()
            g.fill(crown, with: .linearGradient(Gradient(colors: [gold.lighter(0.35).color, gold.color]),
                                                startPoint: CGPoint(x: 50, y: 21), endPoint: CGPoint(x: 50, y: 37.5)))
            g.stroke(crown, with: .color(gold.darker(0.4).color), style: StrokeStyle(lineWidth: 1.7, lineJoin: .round))
            let jewels: [(Double, Color)] = [(44, Color(.sRGB, red: 0.95, green: 0.3, blue: 0.4)),
                                             (50, Color(.sRGB, red: 0.3, green: 0.6, blue: 1.0)),
                                             (56, Color(.sRGB, red: 0.95, green: 0.3, blue: 0.4))]
            for (x, color) in jewels {
                g.fill(Path(ellipseIn: CGRect(x: x - 1.9, y: 31.6, width: 3.8, height: 3.8)), with: .color(color))
            }
        }
    }

    private func drawEffects(_ g: inout GraphicsContext, pose p: Pose) {
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
            d.translateBy(x: 80, y: 40 + phase * 10)
            var drop = Path()
            drop.move(to: CGPoint(x: 0, y: -4.5))
            drop.addQuadCurve(to: CGPoint(x: 0, y: 4), control: CGPoint(x: 5.5, y: 3))
            drop.addQuadCurve(to: CGPoint(x: 0, y: -4.5), control: CGPoint(x: -5.5, y: 3))
            d.fill(drop, with: .color(Color(.sRGB, red: 0.45, green: 0.75, blue: 1)))
        case .sad:
            let phase = (t * 0.45).truncatingRemainder(dividingBy: 1)
            guard phase < 0.7, look.accessory != .shades else { break }
            var tear = g
            tear.opacity = 1 - phase / 0.7
            tear.translateBy(x: 36 + p.tilt * 0.3, y: 61 + phase * 14)
            tear.fill(Path(ellipseIn: CGRect(x: -1.6, y: -2.2, width: 3.2, height: 4.4)),
                      with: .color(Color(.sRGB, red: 0.5, green: 0.78, blue: 1)))
        case .idle:
            break
        }
    }
}
