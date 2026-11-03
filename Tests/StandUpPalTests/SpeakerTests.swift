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

    @Test func ukrainianClipsCoverEveryBuiltInExerciseAndMatchItsName() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources/Voice/uk")
        struct Manifest: Decodable { let clips: [String: String] }
        let clips = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: folder.appendingPathComponent("clips.json"))).clips
        func plain(_ text: String) -> String { text.replacingOccurrences(of: "\u{301}", with: "") }
        let exercises = ExerciseLibrary.builtIn(in: .uk) + [ExerciseLibrary.rest(seconds: 30, in: .uk)]
        let phrases = ["getReady": "Приготуйся", "greatJob": "Чудова робота!", "niceWork": "Молодець!",
                       "preview": "Час розім'ятися. Кола плечима. Чудова робота!"]
        let expected = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) }).merging(phrases) { a, _ in a }
        for (key, text) in expected {
            #expect(clips[key].map(plain) == text, "\(key)")
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("\(key).m4a").path), "\(key)")
        }
        #expect(Set(clips.keys) == Set(expected.keys))
    }

    @Test func clipsPlayUnlessASystemVoiceWasPicked() throws {
        let bundle = FileManager.default.temporaryDirectory.appendingPathComponent("speaker-\(UUID().uuidString)")
        let folder = bundle.appendingPathComponent("Voice/uk")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bundle) }
        try Data().write(to: folder.appendingPathComponent("reach.m4a"))
        let b = try #require(Bundle(url: bundle))
        #expect(Speaker.clipURL("reach", lang: .uk, chosen: nil, bundle: b) != nil)
        #expect(Speaker.clipURL("reach", lang: .uk, chosen: "", bundle: b) != nil)
        #expect(Speaker.clipURL("reach", lang: .uk, chosen: "com.apple.voice.compact.uk-UA.Lesya", bundle: b) == nil)
        #expect(Speaker.clipURL("reach", lang: .ru, chosen: nil, bundle: b) == nil)
        #expect(Speaker.clipURL("custom-1", lang: .uk, chosen: nil, bundle: b) == nil)
        #expect(Speaker.clipURL(nil, lang: .uk, chosen: nil, bundle: b) == nil)
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
