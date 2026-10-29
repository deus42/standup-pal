import Foundation

/// The language picked in Settings. `.system` follows macOS's preferred languages.
enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, en, uk, ru

    var id: String { rawValue }

    /// Each language is named in itself so anyone can find theirs.
    var nativeName: String {
        switch self {
        case .system: return tr("Same as macOS", "Як у системі", "Как в системе")
        case .en: return "English"
        case .uk: return "Українська"
        case .ru: return "Русский"
        }
    }

    var resolved: Lang {
        switch self {
        case .en: return .en
        case .uk: return .uk
        case .ru: return .ru
        case .system:
            // The global list, not this app's own override (see AppStore.preferSystemStrings).
            let global = UserDefaults.standard.persistentDomain(forName: UserDefaults.globalDomain)?["AppleLanguages"] as? [String]
            for identifier in global ?? Locale.preferredLanguages {
                switch identifier.prefix(2).lowercased() {
                case "uk": return .uk
                case "ru": return .ru
                case "en": return .en
                default: continue
                }
            }
            return .en
        }
    }
}

/// A language the UI is actually written in.
enum Lang: String, CaseIterable {
    case en, uk, ru

    var locale: Locale {
        let region = Locale.current.region?.identifier ?? (self == .uk ? "UA" : "US")
        switch self {
        case .en:
            return Locale.current.language.languageCode == .english ? .autoupdatingCurrent : Locale(identifier: "en_\(region)")
        case .uk: return Locale(identifier: "uk_\(region)")
        case .ru: return Locale(identifier: "ru_\(region)")
        }
    }

    var speechCode: String {
        switch self {
        case .en: return "en-US"
        case .uk: return "uk-UA"
        case .ru: return "ru-RU"
        }
    }
}

enum L10n {
    /// Read from views, menus and formatters. Written only on the main thread when the
    /// language setting changes.
    nonisolated(unsafe) static var lang: Lang = .en {
        didSet { if lang != oldValue { Clock.languageDidChange() } }
    }

    static var locale: Locale { lang.locale }
}

/// Every user-facing string is written in all three languages right where it is used,
/// so the compiler guarantees nothing is left untranslated.
func tr(_ en: String, _ uk: String, _ ru: String, in lang: Lang = L10n.lang) -> String {
    switch lang {
    case .en: return en
    case .uk: return uk
    case .ru: return ru
    }
}

enum Plural {
    /// Ukrainian and Russian pick between three forms: 1 день, 2 дні, 5 днів.
    static func slavicIndex(_ n: Int) -> Int {
        let n10 = abs(n) % 10
        let n100 = abs(n) % 100
        if n10 == 1 && n100 != 11 { return 0 }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return 1 }
        return 2
    }

    /// The right noun form for `n`, without the number.
    static func noun(_ n: Int, _ en: [String], _ uk: [String], _ ru: [String], in lang: Lang = L10n.lang) -> String {
        switch lang {
        case .en: return abs(n) == 1 ? en[0] : en[1]
        case .uk: return uk[slavicIndex(n)]
        case .ru: return ru[slavicIndex(n)]
        }
    }
}

/// Counted nouns used across the app, number included.
enum Words {
    static func breaks(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + Plural.noun(n, ["stand-up", "stand-ups"], ["перерва", "перерви", "перерв"],
                              ["перерыв", "перерыва", "перерывов"], in: lang)
    }

    static func days(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + Plural.noun(n, ["day", "days"], ["день", "дні", "днів"], ["день", "дня", "дней"], in: lang)
    }

    static func hours(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + Plural.noun(n, ["hour", "hours"], ["година", "години", "годин"], ["час", "часа", "часов"], in: lang)
    }

    static func minutesLong(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + Plural.noun(n, ["minute", "minutes"], ["хвилина", "хвилини", "хвилин"],
                              ["минута", "минуты", "минут"], in: lang)
    }

    /// "5 min" / "5 хв" / "5 мин": abbreviations need no plural forms.
    static func minutes(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + tr("min", "хв", "мин", in: lang)
    }

    static func seconds(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + tr("s", "с", "с", in: lang)
    }

    static func hoursShort(_ n: Int, in lang: Lang = L10n.lang) -> String {
        "\(n) " + tr("h", "год", "ч", in: lang)
    }
}

/// A fixed phrase in all three languages, for text that is saved with user data
/// (default reminder titles) and must follow a later language switch.
struct Phrase: Equatable {
    let en: String
    let uk: String
    let ru: String

    var current: String { tr(en, uk, ru) }
    func text(in lang: Lang) -> String { tr(en, uk, ru, in: lang) }
    func matches(_ text: String) -> Bool { text == en || text == uk || text == ru }
}
