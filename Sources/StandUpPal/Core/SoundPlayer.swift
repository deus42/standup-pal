import AppKit
import AVFoundation

/// Gentle, synthesized sounds. Nothing is bundled: every cue is a few soft sine
/// partials rendered once into an in-memory WAV and cached.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Cue {
        case reminder, renudge, success, levelUp, snooze, tick, boop
    }

    private var cache: [String: Data] = [:]
    private var players: [AVAudioPlayer] = []
    private var systemSound: NSSound?
    /// Silences everything without touching the user's setting (snapshot runs).
    var isMuted = false

    func play(_ cue: Cue) {
        let s = AppStore.shared.settings
        guard s.soundEnabled else { return }
        play(cue, choice: s.soundChoice, volume: s.volume)
    }

    func preview(_ choice: SoundChoice, volume: Double) {
        play(.reminder, choice: choice, volume: volume)
    }

    private func play(_ cue: Cue, choice: SoundChoice, volume: Double) {
        guard !isMuted else { return }
        let v = Float(max(0, min(1, volume)))
        switch cue {
        case .reminder, .renudge:
            let level = cue == .renudge ? v * 0.7 : v
            switch choice {
            case .tink: playSystem("Tink", volume: level)
            case .glass: playSystem("Glass", volume: level)
            default: playSynth("reminder-\(choice.rawValue)", volume: level) { Synth.reminder(choice) }
            }
        case .success:
            playSynth("success", volume: v * 0.75) { Synth.success() }
        case .levelUp:
            playSynth("levelUp", volume: v * 0.75) { Synth.levelUp() }
        case .snooze:
            playSynth("snooze", volume: v * 0.55) { Synth.snooze() }
        case .tick:
            playSynth("tick", volume: v * 0.35) { Synth.tick() }
        case .boop:
            playSynth("boop", volume: v * 0.5) { Synth.boop() }
        }
    }

    private func playSystem(_ name: String, volume: Float) {
        guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
        systemSound = sound
    }

    private func playSynth(_ key: String, volume: Float, make: () -> [Float]) {
        let data: Data
        if let cached = cache[key] {
            data = cached
        } else {
            data = Synth.wav(make())
            cache[key] = data
        }
        players.removeAll { !$0.isPlaying }
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.prepareToPlay()
        player.play()
        players.append(player)
    }
}

/// A miniature additive synthesizer.
enum Synth {
    static let rate = 44_100.0

    struct Partial {
        var ratio: Double
        var amp: Double
        var decay: Double
    }

    struct Note {
        var freq: Double
        var at: Double
        var gain: Double = 1
        var partials: [Partial]
        var sweepTo: Double? = nil
        var sweepTime: Double = 0.07
    }

    static let bell = [Partial(ratio: 1, amp: 1, decay: 0.55),
                       Partial(ratio: 2, amp: 0.16, decay: 0.22),
                       Partial(ratio: 3, amp: 0.05, decay: 0.1)]
    static let marimba = [Partial(ratio: 1, amp: 1, decay: 0.32),
                          Partial(ratio: 3.93, amp: 0.22, decay: 0.05),
                          Partial(ratio: 9.2, amp: 0.04, decay: 0.02)]
    static let kalimba = [Partial(ratio: 1, amp: 1, decay: 0.7),
                          Partial(ratio: 2, amp: 0.06, decay: 0.2),
                          Partial(ratio: 5.4, amp: 0.1, decay: 0.04)]
    static let pop = [Partial(ratio: 1, amp: 1, decay: 0.06)]

    static func reminder(_ choice: SoundChoice) -> [Float] {
        switch choice {
        case .marimba:
            return render([Note(freq: 659.3, at: 0, partials: marimba),
                           Note(freq: 880, at: 0.14, partials: marimba)], length: 0.9)
        case .kalimba:
            return render([Note(freq: 587.3, at: 0, partials: kalimba),
                           Note(freq: 880, at: 0.16, gain: 0.8, partials: kalimba)], length: 1.4)
        case .bubble:
            return render([Note(freq: 380, at: 0, partials: pop, sweepTo: 820),
                           Note(freq: 520, at: 0.13, gain: 0.8, partials: pop, sweepTo: 1100)], length: 0.45)
        case .softChime, .tink, .glass:
            return render([Note(freq: 784, at: 0, partials: bell),
                           Note(freq: 1046.5, at: 0.17, gain: 0.85, partials: bell)], length: 1.4)
        }
    }

    static func success() -> [Float] {
        let notes = [523.25, 659.25, 783.99, 1046.5].enumerated().map { index, freq in
            Note(freq: freq, at: Double(index) * 0.085, gain: 0.8, partials: marimba)
        }
        return render(notes, length: 0.9)
    }

    static func levelUp() -> [Float] {
        let notes = [587.3, 740, 880, 1174.7, 1480].enumerated().map { index, freq in
            Note(freq: freq, at: Double(index) * 0.075, gain: 0.7, partials: kalimba)
        }
        return render(notes, length: 1.4)
    }

    static func snooze() -> [Float] {
        render([Note(freq: 880, at: 0, gain: 0.7, partials: bell),
                Note(freq: 659.3, at: 0.14, gain: 0.6, partials: bell)], length: 0.9)
    }

    static func tick() -> [Float] {
        render([Note(freq: 1318.5, at: 0, partials: [Partial(ratio: 1, amp: 1, decay: 0.03)])], length: 0.12)
    }

    static func boop() -> [Float] {
        render([Note(freq: 520, at: 0, partials: pop, sweepTo: 760, sweepTime: 0.05)], length: 0.2)
    }

    static func render(_ notes: [Note], length: Double) -> [Float] {
        let count = Int(length * rate)
        var out = [Double](repeating: 0, count: count)
        for note in notes {
            let start = Int(note.at * rate)
            guard start < count else { continue }
            for partial in note.partials {
                var phase = 0.0
                for i in start..<count {
                    let t = Double(i - start) / rate
                    var freq = note.freq
                    if let target = note.sweepTo {
                        freq += (target - note.freq) * min(1, t / note.sweepTime)
                    }
                    phase += 2 * Double.pi * freq * partial.ratio / rate
                    let envelope = min(1, t / 0.005) * exp(-t / partial.decay)
                    if t > 0.02 && envelope < 0.0004 { break }
                    out[i] += sin(phase) * partial.amp * envelope * note.gain
                }
            }
        }
        let peak = out.map(abs).max() ?? 0
        let scale = peak > 0 ? 0.85 / peak : 0
        let fade = Int(0.01 * rate)
        return out.enumerated().map { i, value in
            var sample = value * scale
            if i > count - fade { sample *= Double(count - i) / Double(fade) }
            return Float(sample)
        }
    }

    /// 16-bit mono PCM WAV.
    static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        let sampleRate = UInt32(rate)
        let byteCount = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36) + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(sampleRate)
        append(sampleRate * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(byteCount)
        data.reserveCapacity(data.count + samples.count * 2)
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * 32_767))
        }
        return data
    }
}
