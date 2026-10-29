import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value if present and valid, otherwise falls back. Keeps old saved data
    /// readable when new settings are added.
    func value<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

enum WarmUpLength: Int, Codable, CaseIterable, Identifiable {
    case quick = 120
    case standard = 180
    case full = 300

    var id: Int { rawValue }
    var minutes: Int { rawValue / 60 }

    var label: String {
        switch self {
        case .quick: return "Quick · 2 min"
        case .standard: return "Standard · 3 min"
        case .full: return "Full · 5 min"
        }
    }
}

enum SoundChoice: String, Codable, CaseIterable, Identifiable {
    case softChime, marimba, kalimba, bubble, tink, glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .softChime: return "Soft chime"
        case .marimba: return "Marimba"
        case .kalimba: return "Kalimba"
        case .bubble: return "Bubble pop"
        case .tink: return "Tink (system)"
        case .glass: return "Glass (system)"
        }
    }
}

enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case blob, kitty, bunny, bear

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blob: return "Blob"
        case .kitty: return "Kitty"
        case .bunny: return "Bunny"
        case .bear: return "Bear"
        }
    }
}

enum PetAccessory: String, Codable, CaseIterable, Identifiable {
    case none, sprout, sweatband, partyHat, shades, crown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .sprout: return "Sprout"
        case .sweatband: return "Sweatband"
        case .partyHat: return "Party hat"
        case .shades: return "Cool shades"
        case .crown: return "Crown"
        }
    }

    var emoji: String {
        switch self {
        case .none: return "✨"
        case .sprout: return "🌱"
        case .sweatband: return "🎽"
        case .partyHat: return "🥳"
        case .shades: return "😎"
        case .crown: return "👑"
        }
    }

    var unlockLevel: Int {
        switch self {
        case .none: return 1
        case .sprout: return 2
        case .sweatband: return 4
        case .partyHat: return 6
        case .shades: return 8
        case .crown: return 10
        }
    }
}

struct AppSettings: Codable, Equatable {
    // Schedule
    var workStartMinute = 9 * 60
    var workEndMinute = 18 * 60
    var workDays: Set<Int> = [2, 3, 4, 5, 6]
    var intervalMinutes = 60
    var leadMinutes = 5
    var snoozeMinutes = 5
    var dailyGoal = 6
    var lunchEnabled = false
    var lunchStartMinute = 13 * 60
    var lunchEndMinute = 14 * 60

    // Smart behaviour
    var smartAway = true
    var holdDuringCalls = true
    var renudge = true
    var showCountdown = true

    // Sound
    var soundEnabled = true
    var soundChoice: SoundChoice = .softChime
    var volume: Double = 0.5

    // Pet
    var petEnabled = true
    var petName = "Pip"
    var petSpecies: PetSpecies = .blob
    var petColorHex = "#7ED6B2"
    var petAccessory: PetAccessory = .none

    // Warm-up
    var warmUpLength: WarmUpLength = .standard
    var speakExercises = false
    var getReadyCountdown = true
    var disabledExerciseIDs: Set<String> = []
    var customExercises: [Exercise] = []
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        workStartMinute = c.value(.workStartMinute, workStartMinute)
        workEndMinute = c.value(.workEndMinute, workEndMinute)
        workDays = c.value(.workDays, workDays)
        intervalMinutes = c.value(.intervalMinutes, intervalMinutes)
        leadMinutes = c.value(.leadMinutes, leadMinutes)
        snoozeMinutes = c.value(.snoozeMinutes, snoozeMinutes)
        dailyGoal = c.value(.dailyGoal, dailyGoal)
        lunchEnabled = c.value(.lunchEnabled, lunchEnabled)
        lunchStartMinute = c.value(.lunchStartMinute, lunchStartMinute)
        lunchEndMinute = c.value(.lunchEndMinute, lunchEndMinute)
        smartAway = c.value(.smartAway, smartAway)
        holdDuringCalls = c.value(.holdDuringCalls, holdDuringCalls)
        renudge = c.value(.renudge, renudge)
        showCountdown = c.value(.showCountdown, showCountdown)
        soundEnabled = c.value(.soundEnabled, soundEnabled)
        soundChoice = c.value(.soundChoice, soundChoice)
        volume = c.value(.volume, volume)
        petEnabled = c.value(.petEnabled, petEnabled)
        petName = c.value(.petName, petName)
        petSpecies = c.value(.petSpecies, petSpecies)
        petColorHex = c.value(.petColorHex, petColorHex)
        petAccessory = c.value(.petAccessory, petAccessory)
        warmUpLength = c.value(.warmUpLength, warmUpLength)
        speakExercises = c.value(.speakExercises, speakExercises)
        getReadyCountdown = c.value(.getReadyCountdown, getReadyCountdown)
        disabledExerciseIDs = c.value(.disabledExerciseIDs, disabledExerciseIDs)
        customExercises = c.value(.customExercises, customExercises)
    }
}
