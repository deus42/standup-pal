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
        case .quick: return tr("Quick · 2 min", "Швидка · 2 хв", "Быстрая · 2 мин")
        case .standard: return tr("Standard · 3 min", "Звичайна · 3 хв", "Обычная · 3 мин")
        case .full: return tr("Full · 5 min", "Повна · 5 хв", "Полная · 5 мин")
        }
    }
}

enum SoundChoice: String, Codable, CaseIterable, Identifiable {
    case softChime, marimba, kalimba, bubble, tink, glass

    var id: String { rawValue }

    var label: String {
        switch self {
        case .softChime: return tr("Soft chime", "М'який дзвін", "Мягкий звон")
        case .marimba: return tr("Marimba", "Марімба", "Маримба")
        case .kalimba: return tr("Kalimba", "Калімба", "Калимба")
        case .bubble: return tr("Bubble pop", "Бульбашка", "Пузырёк")
        case .tink: return tr("Tink (system)", "Tink (системний)", "Tink (системный)")
        case .glass: return tr("Glass (system)", "Glass (системний)", "Glass (системный)")
        }
    }
}

enum PetSpecies: String, Codable, CaseIterable, Identifiable {
    case blob, booty, kitty, bunny, bear, panda, fox, puppy, hamster, penguin, frog, chick, axolotl, dino

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blob: return tr("Blob", "Блоб", "Блоб")
        case .booty: return tr("Booty", "Попка", "Попка")
        case .kitty: return tr("Kitty", "Котик", "Котик")
        case .bunny: return tr("Bunny", "Зайчик", "Зайка")
        case .bear: return tr("Bear", "Ведмедик", "Мишка")
        case .panda: return tr("Panda", "Панда", "Панда")
        case .fox: return tr("Fox", "Лисичка", "Лисичка")
        case .puppy: return tr("Puppy", "Цуцик", "Щенок")
        case .hamster: return tr("Hamster", "Хом'ячок", "Хомяк")
        case .penguin: return tr("Penguin", "Пінгвін", "Пингвин")
        case .frog: return tr("Frog", "Жабка", "Лягушка")
        case .chick: return tr("Chick", "Курча", "Цыплёнок")
        case .axolotl: return tr("Axolotl", "Аксолотль", "Аксолотль")
        case .dino: return tr("Dino", "Дино", "Дино")
        }
    }

    /// Every pet is a fitness pet with its own sport.
    var role: String {
        switch self {
        case .blob: return tr("Gym buddy", "Напарник", "Напарник")
        case .booty: return tr("Squat pro", "Профі присідань", "Профи приседаний")
        case .kitty: return tr("Yoga master", "Майстер йоги", "Мастер йоги")
        case .bunny: return tr("Sprinter", "Спринтер", "Спринтер")
        case .bear: return tr("Powerlifter", "Пауерліфтер", "Пауэрлифтер")
        case .panda: return tr("Kung fu", "Кунг-фу", "Кунг-фу")
        case .fox: return tr("Trail runner", "Бігун", "Бегун")
        case .puppy: return tr("Fetch champ", "Чемпіон апорту", "Чемпион апорта")
        case .hamster: return tr("Wheel runner", "Біг у колесі", "Бег в колесе")
        case .penguin: return tr("Swimmer", "Плавець", "Пловец")
        case .frog: return tr("High jumper", "Стрибун", "Прыгун")
        case .chick: return tr("Coach", "Тренер", "Тренер")
        case .axolotl: return tr("Aqua aerobics", "Аквааеробіка", "Аквааэробика")
        case .dino: return tr("Cardio-saurus", "Кардіозавр", "Кардиозавр")
        }
    }
}

/// Fitness gear the pet earns by levelling up. Each slot holds one item.
protocol PetGear: CaseIterable, Identifiable, Equatable {
    var label: String { get }
    var unlockLevel: Int { get }
}

enum HeadGear: String, Codable, PetGear {
    case none, sweatband, cap, headphones, shades, crown

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return tr("None", "Нічого", "Ничего")
        case .sweatband: return tr("Sweatband", "Пов'язка", "Повязка")
        case .cap: return tr("Cap", "Кепка", "Кепка")
        case .headphones: return tr("Headphones", "Навушники", "Наушники")
        case .shades: return tr("Shades", "Окуляри", "Очки")
        case .crown: return tr("Crown", "Корона", "Корона")
        }
    }

    var unlockLevel: Int {
        switch self {
        case .none, .sweatband: return 1
        case .cap: return 3
        case .headphones: return 6
        case .shades: return 9
        case .crown: return 12
        }
    }
}

enum HandGear: String, Codable, PetGear {
    case none, bottle, dumbbells, kettlebell, trophy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return tr("None", "Нічого", "Ничего")
        case .bottle: return tr("Water bottle", "Пляшка води", "Бутылка воды")
        case .dumbbells: return tr("Dumbbells", "Гантелі", "Гантели")
        case .kettlebell: return tr("Kettlebell", "Гиря", "Гиря")
        case .trophy: return tr("Trophy", "Кубок", "Кубок")
        }
    }

    var unlockLevel: Int {
        switch self {
        case .none: return 1
        case .bottle: return 2
        case .dumbbells: return 5
        case .kettlebell: return 8
        case .trophy: return 15
        }
    }
}

enum NeckGear: String, Codable, PetGear {
    case none, towel, whistle, medal

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return tr("None", "Нічого", "Ничего")
        case .towel: return tr("Towel", "Рушник", "Полотенце")
        case .whistle: return tr("Whistle", "Свисток", "Свисток")
        case .medal: return tr("Medal", "Медаль", "Медаль")
        }
    }

    var unlockLevel: Int {
        switch self {
        case .none: return 1
        case .towel: return 4
        case .whistle: return 7
        case .medal: return 10
        }
    }
}

enum GearCatalog {
    /// Names of gear that unlock after `oldLevel`, up to and including `newLevel`.
    static func unlocked(after oldLevel: Int, through newLevel: Int) -> [String] {
        func pick<G: PetGear>(_ all: [G]) -> [(Int, String)] {
            all.filter { $0.unlockLevel > oldLevel && $0.unlockLevel <= newLevel }.map { ($0.unlockLevel, $0.label) }
        }
        let items = pick(HeadGear.allCases) + pick(HandGear.allCases) + pick(NeckGear.allCases)
        return items.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// The next piece of gear to earn, for "next unlock" hints.
    static func next(after level: Int) -> (level: Int, label: String)? {
        var all: [(Int, String)] = []
        all += HeadGear.allCases.map { ($0.unlockLevel, $0.label) }
        all += HandGear.allCases.map { ($0.unlockLevel, $0.label) }
        all += NeckGear.allCases.map { ($0.unlockLevel, $0.label) }
        return all.filter { $0.0 > level }.min { $0.0 < $1.0 }.map { (level: $0.0, label: $0.1) }
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

    // Language
    var language: AppLanguage = .system

    // Sound
    var soundEnabled = true
    var soundChoice: SoundChoice = .softChime
    var volume: Double = 0.5

    // Pet
    var petEnabled = true
    var petName = "Pip"
    var petSpecies: PetSpecies = .blob
    var petColorHex = "#7ED6B2"
    /// The belly and face tone; empty means "a light tint of the body colour".
    var petBellyHex = ""
    var petHead: HeadGear = .sweatband
    var petHands: HandGear = .none
    var petNeck: NeckGear = .none

    // Warm-up
    var warmUpLength: WarmUpLength = .standard
    var speakExercises = false
    var getReadyCountdown = true
    var disabledExerciseIDs: Set<String> = []
    var customExercises: [Exercise] = []
}

extension AppSettings {
    private enum LegacyKeys: String, CodingKey {
        case petAccessory
    }

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
        language = c.value(.language, language)
        soundEnabled = c.value(.soundEnabled, soundEnabled)
        soundChoice = c.value(.soundChoice, soundChoice)
        volume = c.value(.volume, volume)
        petEnabled = c.value(.petEnabled, petEnabled)
        petName = c.value(.petName, petName)
        petSpecies = c.value(.petSpecies, petSpecies)
        petColorHex = c.value(.petColorHex, petColorHex)
        petBellyHex = c.value(.petBellyHex, petBellyHex)
        if c.contains(.petHead) {
            petHead = c.value(.petHead, petHead)
        } else if let legacy = try? decoder.container(keyedBy: LegacyKeys.self),
                  let old = HeadGear(rawValue: legacy.value(.petAccessory, "")), old != .none {
            // v1 had a single accessory; the head-worn ones carry over.
            petHead = old
        }
        petHands = c.value(.petHands, petHands)
        petNeck = c.value(.petNeck, petNeck)
        warmUpLength = c.value(.warmUpLength, warmUpLength)
        speakExercises = c.value(.speakExercises, speakExercises)
        getReadyCountdown = c.value(.getReadyCountdown, getReadyCountdown)
        disabledExerciseIDs = c.value(.disabledExerciseIDs, disabledExerciseIDs)
        customExercises = c.value(.customExercises, customExercises)
    }
}
