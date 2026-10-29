import AppKit
import SwiftUI

/// In the macOS 27 SDK `@State` resolves to a macro whose plugin only ships with full
/// Xcode. Spelling the property wrapper through a typealias keeps Command Line Tools
/// builds working.
typealias ViewState<Value> = SwiftUICore.State<Value>

// MARK: Buttons

struct PillButtonStyle: ButtonStyle {
    var prominent = false
    var tint: Color = .accentColor
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        PillBody(configuration: configuration, prominent: prominent, tint: tint, compact: compact)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        let tint: Color
        let compact: Bool
        @ViewState private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: compact ? 12 : 13, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .padding(.horizontal, compact ? 10 : 14)
                .padding(.vertical, compact ? 5 : 8)
                .frame(maxWidth: prominent ? .infinity : nil)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(
                    Capsule().fill(prominent
                        ? AnyShapeStyle(tint.gradient)
                        : AnyShapeStyle(Color.primary.opacity(hovering ? 0.13 : 0.07)))
                )
                .overlay(Capsule().strokeBorder(Color.primary.opacity(prominent ? 0 : 0.08)))
                .brightness(prominent && hovering ? 0.05 : 0)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .opacity(isEnabled ? 1 : 0.45)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.12), value: hovering)
                .contentShape(Capsule())
                .onHover { hovering = $0 }
        }
    }
}

// MARK: Speech bubble

struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 15)
            .background(
                BubbleShape()
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.94))
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
            )
            .animation(.easeInOut(duration: 0.2), value: text)
    }
}

struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let tail: CGFloat = 7
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        var p = Path(roundedRect: body, cornerRadius: 12, style: .continuous)
        p.move(to: CGPoint(x: rect.midX - 8, y: body.maxY - 0.5))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 1, y: rect.maxY), control: CGPoint(x: rect.midX - 1, y: body.maxY + 3))
        p.addQuadCurve(to: CGPoint(x: rect.midX + 7, y: body.maxY - 0.5), control: CGPoint(x: rect.midX + 3, y: body.maxY + 2))
        p.closeSubpath()
        return p
    }
}

// MARK: Progress

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 6
    var tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
    }
}

struct StatTile: View {
    let title: String
    let value: String
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.045)))
    }
}

struct LevelBadge: View {
    let level: Int
    let tint: Color

    var body: some View {
        Text(tr("Lv \(level)", "Рів. \(level)", "Ур. \(level)"))
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .foregroundStyle(.white)
            .background(Capsule().fill(tint.gradient))
    }
}

struct ToastBanner: View {
    let toast: Toast
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.system(size: 13, weight: .bold, design: .rounded))
                Text(toast.message).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color.yellow.opacity(0.25), Color.orange.opacity(0.15)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: Weekdays

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    var tint: Color = .accentColor
    var dayWidth: CGFloat = 36

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Clock.orderedWeekdays, id: \.self) { weekday in
                let on = selection.contains(weekday)
                Button {
                    if on { selection.remove(weekday) } else { selection.insert(weekday) }
                } label: {
                    Text(Clock.shortWeekdaySymbol(weekday))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(width: dayWidth, height: 24)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(on ? AnyShapeStyle(tint) : AnyShapeStyle(Color.primary.opacity(0.07))))
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Bridges "minutes since midnight" to DatePicker's Date.
func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
    Binding(
        get: { Clock.date(on: Date(), minute: minutes.wrappedValue) },
        set: { minutes.wrappedValue = Clock.minuteOfDay($0) }
    )
}

// MARK: Confetti

struct ConfettiView: View {
    var colors: [Color]
    @ViewState private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                guard t < 4 else { return }
                for i in 0..<80 {
                    var rng = SplitMix(seed: UInt64(i + 1) &* 0x9E37_79B9_7F4A_7C15)
                    let x0 = size.width * (0.2 + rng.unit() * 0.6)
                    let vx = (rng.unit() - 0.5) * 360
                    let vy = -(rng.unit() * 380 + 220)
                    let delay = rng.unit() * 0.25
                    let spin = (rng.unit() - 0.5) * 14
                    let tt = t - delay
                    guard tt > 0 else { continue }
                    let x = x0 + vx * tt
                    let y = size.height * 0.62 + vy * tt + 0.5 * 520 * tt * tt
                    guard y < size.height + 20 else { continue }
                    var piece = context
                    piece.opacity = max(0, 1 - tt / 3.5)
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(spin * tt))
                    let rect = i % 3 == 0
                        ? CGRect(x: -3.5, y: -3.5, width: 7, height: 7)
                        : CGRect(x: -2.5, y: -6, width: 5, height: 12)
                    let path = i % 3 == 0 ? Path(ellipseIn: rect) : Path(roundedRect: rect, cornerRadius: 1.5)
                    piece.fill(path, with: .color(colors[i % colors.count]))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

// MARK: Settings layout

/// A titled, rounded group in the style of System Settings, without the scroll view a
/// grouped `Form` brings: settings windows size themselves to their content.
struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color.primary.opacity(0.04)))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color.primary.opacity(0.07)))
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One line in a `SettingsGroup`: a label on the left, a control on the right.
struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var divider = true
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13))
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 36)
            if divider {
                Divider().padding(.leading, 12)
            }
        }
    }
}

/// A toggle row with a small switch.
struct SettingsToggle: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var divider = true

    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, divider: divider) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

/// A stepper whose value is shown as text next to it.
struct ValueStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step = 1
    var label: (Int) -> String

    var body: some View {
        HStack(spacing: 6) {
            Text(label(value)).monospacedDigit().foregroundStyle(.secondary)
            Stepper("", value: $value, in: range, step: step).labelsHidden()
        }
    }
}

/// Reports a view's height so AppKit can size the window around it.
struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: AppKit glue

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}
