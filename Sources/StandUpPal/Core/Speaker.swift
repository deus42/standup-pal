import AppKit
import AVFoundation

/// Reads warm-ups aloud. macOS comes with only a small "compact" voice for most languages,
/// and it sounds robotic. Enhanced and Premium voices sound far better but have to be
/// downloaded in System Settings, so the best installed voice wins unless one was chosen.
@MainActor
final class Speaker {
    static let shared = Speaker()

    /// Silences speech without touching the user's setting (snapshot runs).
    var isMuted = false

    private let synth = AVSpeechSynthesizer()

    func say(_ text: String) {
        guard !isMuted else { return }
        let settings = AppStore.shared.settings
        synth.stopSpeaking(at: .word)
        let voice = Self.voice(for: L10n.lang, chosen: settings.speechVoices[L10n.lang.rawValue])
        let utterance = AVSpeechUtterance(string: Self.spoken(text))
        utterance.voice = voice
        // Basic voices rush through words at the default speed.
        if voice?.quality == .default { utterance.rate = 0.45 }
        utterance.volume = Float(max(0.2, settings.volume))
        synth.speak(utterance)
    }

    func preview() {
        say(tr("Time to stretch. Shoulder rolls. Great job!",
               "Час розім'ятися. Кола плечима. Чудова робота!",
               "Пора размяться. Круги плечами. Отличная работа!"))
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: Voices

    /// Installed voices for a language, best first.
    static func voices(for lang: Lang) -> [AVSpeechSynthesisVoice] {
        let systemDefault = AVSpeechSynthesisVoice(language: lang.speechCode)?.identifier
        func score(_ voice: AVSpeechSynthesisVoice) -> Int {
            rank(identifier: voice.identifier, language: voice.language, quality: voice.quality,
                 preferredLanguage: lang.speechCode, systemDefault: systemDefault)
        }
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(lang.rawValue) && $0.voiceTraits.isDisjoint(with: [.isNoveltyVoice, .isPersonalVoice]) }
            .sorted { (score($0), $1.name) > (score($1), $0.name) }
    }

    /// The chosen voice when it's installed on this Mac (settings sync between Macs that may
    /// not have the same voices), otherwise the best one.
    static func voice(for lang: Lang, chosen: String?) -> AVSpeechSynthesisVoice? {
        let installed = voices(for: lang)
        return installed.first { $0.identifier == chosen } ?? installed.first
    }

    nonisolated static func rank(identifier: String, language: String, quality: AVSpeechSynthesisVoiceQuality,
                     preferredLanguage: String, systemDefault: String?) -> Int {
        var score = quality.rawValue * 10
        if identifier.contains("super-compact") { score -= 5 }
        if language == preferredLanguage { score += 2 }
        if identifier == systemDefault { score += 1 }
        return score
    }

    static func label(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = tr("premium", "преміум", "премиум")
        case .enhanced: quality = tr("enhanced", "покращений", "улучшенный")
        default: quality = tr("basic", "базовий", "базовый")
        }
        return "\(voice.name) · \(quality)"
    }

    /// Emoji are read out by name, and Lesya can't say the Ukrainian apostrophe sign, so
    /// names are tidied first. A full stop makes each name a finished phrase.
    nonisolated static func spoken(_ text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            let p = scalar.properties
            return !(p.isEmojiPresentation || (p.isEmoji && scalar.value > 0xFF)
                     || scalar.value == 0x200D || (0xFE00...0xFE0F).contains(scalar.value))
        }
        var s = String(String.UnicodeScalarView(scalars)).replacingOccurrences(of: "\u{2BC}", with: "'")
        s = s.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        if let last = s.last, last.isLetter || last.isNumber { s += "." }
        return s
    }

    /// System Settings › Accessibility › Spoken Content ("Read & Speak" in newer macOS),
    /// where voices are downloaded.
    static func openVoiceSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent") {
            NSWorkspace.shared.open(url)
        }
    }
}
