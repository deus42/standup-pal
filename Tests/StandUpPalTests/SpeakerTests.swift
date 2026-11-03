import AVFoundation
import Foundation
import Testing
@testable import StandUpPal

@Suite("Reading warm-ups aloud")
struct SpeakerTests {
    private func rank(_ id: String, _ quality: AVSpeechSynthesisVoiceQuality, language: String = "uk-UA",
                      systemDefault: String? = nil) -> Int {
        Speaker.rank(identifier: id, language: language, quality: quality, preferredLanguage: "uk-UA", systemDefault: systemDefault)
    }

    @Test func betterVoicesWinOverTheBundledCompactOne() {
        let compact = rank("com.apple.voice.compact.uk-UA.Lesya", .default, systemDefault: "com.apple.voice.compact.uk-UA.Lesya")
        let superCompact = rank("com.apple.voice.super-compact.uk-UA.Lesya", .default)
        let enhanced = rank("com.apple.voice.enhanced.uk-UA.Lesya", .enhanced)
        let premium = rank("com.apple.voice.premium.uk-UA.Lesya", .premium)
        #expect(premium > enhanced && enhanced > compact && compact > superCompact)
        // The language's own region beats another region of the same quality.
        #expect(rank("a", .enhanced, language: "uk-RU") < rank("b", .enhanced))
    }

    @Test func namesAreTidiedBeforeTheyAreSpoken() {
        #expect(Speaker.spoken("Кола плечима") == "Кола плечима.")
        #expect(Speaker.spoken("Відпочинок 😮‍💨") == "Відпочинок.")
        #expect(Speaker.spoken("🏃 Випади  на місці!") == "Випади на місці!")
        #expect(Speaker.spoken("Розтяжка зап\u{2BC}ястків") == "Розтяжка зап'ястків.")
        #expect(Speaker.spoken("3 кола") == "3 кола.")
        #expect(Speaker.spoken("") == "")
    }

    @Test func voiceChoicesDecodeFromOldSettings() throws {
        let old = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"speakExercises":true}"#.utf8))
        #expect(old.speakExercises && old.speechVoices.isEmpty)
        var s = AppSettings()
        s.speechVoices["uk"] = "com.apple.voice.enhanced.uk-UA.Lesya"
        let back = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(s))
        #expect(back.speechVoices == ["uk": "com.apple.voice.enhanced.uk-UA.Lesya"])
    }
}
