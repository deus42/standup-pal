import Foundation

/// What the pet says in its speech bubble. Lines rotate slowly and on every tap.
/// Ukrainian and Russian lines avoid gendered verb forms: neither the pet's nor the
/// user's gender is known.
@MainActor
enum PetTalk {
    static func line(store: AppStore, scheduler: Scheduler, now: Date) -> String {
        let s = store.settings
        let nonce = store.talkNonce
        let name = s.petName

        if store.showWelcome {
            let lead = s.leadMinutes
            return tr("Hi, I'm \(name)! 👋 I'll nudge you to stand up \(lead) min before every hour. Right-click me in the menu bar for quick options.",
                      "Привіт, я \(name)! 👋 Нагадуватиму тобі встати за \(lead) хв до кінця кожної години. Клацни на мене правою кнопкою в рядку меню — там швидкі налаштування.",
                      "Привет, я \(name)! 👋 Буду напоминать тебе встать за \(lead) мин до конца каждого часа. Кликни по мне правой кнопкой в строке меню — там быстрые настройки.")
        }
        if scheduler.active != nil {
            return tr("It's time! Up, up, up! 🧍", "Час! Встаємо, встаємо! 🧍", "Пора! Встаём, встаём! 🧍")
        }
        if let reason = scheduler.holdReason, !scheduler.queue.isEmpty {
            let device = deviceName(reason)
            return tr("Shh… your \(device) is on. I'll wave as soon as your call ends. 🤫",
                      "Тсс… бачу, ти на дзвінку (\(device)). Помахаю, щойно він закінчиться. 🤫",
                      "Тсс… вижу, ты на звонке (\(device)). Помашу, как только он закончится. 🤫")
        }
        if let reaction = store.reaction, store.reactionUntil > now {
            switch reaction {
            case .celebrate:
                return pick(lines(["WOOO! That was awesome! 🎉", "Look at you go! So proud of you. 💪", "Stretchy legend status: confirmed. ✨"],
                                  ["ВАУ! Це було чудово! 🎉", "Оце так! Пишаюся тобою. 💪", "Статус легенди розтяжки: підтверджено. ✨"],
                                  ["УРА! Это было круто! 🎉", "Вот это да! Горжусь тобой. 💪", "Статус легенды растяжки: подтверждён. ✨"]), now, nonce)
            case .happy:
                return pick(lines(["Hehe, that tickles! 💚", "Yay! Thank you! ✨", "You're the best human. 🥰", "Boop! 💫"],
                                  ["Хі-хі, лоскотно! 💚", "Ура! Дякую! ✨", "Ти найкраща людина. 🥰", "Буп! 💫"],
                                  ["Хи-хи, щекотно! 💚", "Ура! Спасибо! ✨", "Ты лучший человек на свете. 🥰", "Буп! 💫"]), now, nonce)
            case .sad:
                return pick(lines(["Aww… okay. Next time? 🥺", "My tiny legs were ready… 😔", "I'll be here. Still stretching. Alone."],
                                  ["Ох… гаразд. Наступного разу? 🥺", "А мої лапки вже були готові… 😔", "Я тут. Розтягуюсь. Сам на сам."],
                                  ["Эх… ладно. В следующий раз? 🥺", "А мои лапки уже были готовы… 😔", "Я тут. Тянусь. В одиночестве."]), now, nonce)
            default:
                break
            }
        }
        if scheduler.isPaused(now), let until = store.runtime.pausedUntil {
            let time = Clock.time(until)
            return tr("Taking a break from nagging until \(time). Zzz… 😴", "Не нагадую до \(time). Хр-р… 😴", "Не напоминаю до \(time). Хр-р… 😴")
        }

        let done = store.today.standupsDone
        if !scheduler.isWorkingTime(now) {
            let isWorkDay = s.workDays.contains(Clock.weekday(now))
            if isWorkDay, Clock.minuteOfDay(now) < s.workStartMinute, let next = scheduler.nextStandup {
                let time = Clock.time(next)
                return tr("Good morning! ☀️ First stretch at \(time).", "Доброго ранку! ☀️ Перша розминка о \(time).",
                          "Доброе утро! ☀️ Первая разминка в \(time).")
            }
            if done > 0 {
                let count = Words.breaks(done)
                return tr("Off the clock! \(count) today. Proud of you. 🌙",
                          "Робочий день скінчився! Сьогодні на рахунку \(count). Пишаюся тобою. 🌙",
                          "Рабочий день окончен! Сегодня на счету \(count). Горжусь тобой. 🌙")
            }
            return pick(lines(["Zzz… it's not work o'clock. 💤", "Off the clock! Go do something fun. 🌙", "Resting my tiny legs for the next work day."],
                              ["Хр-р… зараз не робочий час. 💤", "Робочий день позаду! Займися чимось приємним. 🌙", "Відпочиваю лапками до наступного робочого дня."],
                              ["Хр-р… сейчас не рабочее время. 💤", "Рабочий день позади! Займись чем-нибудь приятным. 🌙", "Отдыхаю лапками до следующего рабочего дня."]),
                        now, nonce)
        }

        if let next = scheduler.nextStandup {
            let seconds = next.timeIntervalSince(now)
            if seconds <= 5 * 60 {
                let soon = Clock.minutesLabel(seconds)
                return tr("Stretch time in \(soon). Get those legs ready! 🦵", "Розминка через \(soon). Готуй ноги! 🦵",
                          "Разминка через \(soon). Готовь ноги! 🦵")
            }
        }
        if store.pet.happiness < 30 {
            return pick(lines(["I miss our stretches… maybe the next one? 🥺", "Feeling a bit stiff. Wanna stretch together?"],
                              ["Сумую за нашими розминками… може, наступну зробимо? 🥺", "Щось усе затерпло. Розімнемося разом?"],
                              ["Скучаю по нашим разминкам… может, следующую сделаем? 🥺", "Что-то всё затекло. Разомнёмся вместе?"]), now, nonce)
        }
        if done >= s.dailyGoal {
            let count = Words.breaks(done)
            return pick(lines(["Daily goal smashed! You're a legend. 🏆", "\(count) today! My legs are proud of your legs."],
                              ["Денну мету розгромлено! Ти легенда. 🏆", "Уже \(count) сьогодні! Мої лапки пишаються твоїми ногами."],
                              ["Дневная цель разгромлена! Ты легенда. 🏆", "Уже \(count) сегодня! Мои лапки гордятся твоими ногами."]), now, nonce)
        }
        return pick(idleLines, now, nonce)
    }

    static func deviceName(_ reason: String) -> String {
        reason == "camera" ? tr("camera", "камера", "камера") : tr("microphone", "мікрофон", "микрофон")
    }

    private static var idleLines: [String] {
        lines([
            "Sip of water? 💧 I'll wait.",
            "Shoulders down, jaw unclenched. There you go.",
            "Blink a few times. Your eyes will thank you. 👀",
            "Every stretch gives me XP. I'm basically a gym pet.",
            "Posture check! Pretend a string pulls your head up. 🎈",
            "Counting down with you. Tick… tock…",
            "Idea: stand up for your next call.",
            "You're doing great. I mean it. 💚",
            "I've been practising squats. Mostly the sitting part.",
            "Tap me. Go on. I dare you.",
            "Fun fact: standing burns more energy than sitting. Science! 🔬",
            "New gear unlocks as we level up. I want the crown. 👑",
        ], [
            "Ковток води? 💧 Я зачекаю.",
            "Плечі вниз, щелепу розслаб. Ось так.",
            "Покліпай кілька разів. Очі скажуть дякую. 👀",
            "Кожна розминка дає мені XP. Я, по суті, фітнес-улюбленець.",
            "Перевірка постави! Уяви, що ниточка тягне маківку вгору. 🎈",
            "Рахую разом з тобою. Тік… так…",
            "Ідея: наступний дзвінок — стоячи.",
            "У тебе все виходить. Чесно. 💚",
            "Я треную присідання. Переважно ту частину, де сидиш.",
            "Тицьни на мене. Ну ж бо. Слабо?",
            "Цікавий факт: стоячи витрачаєш більше енергії, ніж сидячи. Наука! 🔬",
            "Нове спорядження відкривається з рівнями. Я хочу корону. 👑",
        ], [
            "Глоток воды? 💧 Я подожду.",
            "Плечи вниз, челюсть расслабь. Вот так.",
            "Поморгай несколько раз. Глаза скажут спасибо. 👀",
            "Каждая разминка даёт мне XP. Я, по сути, фитнес-питомец.",
            "Проверка осанки! Представь, что ниточка тянет макушку вверх. 🎈",
            "Считаю вместе с тобой. Тик… так…",
            "Идея: следующий звонок — стоя.",
            "У тебя всё получается. Честно. 💚",
            "Я тренирую приседания. В основном ту часть, где сидишь.",
            "Ткни в меня. Ну же. Слабо?",
            "Интересный факт: стоя тратишь больше энергии, чем сидя. Наука! 🔬",
            "Новое снаряжение открывается с уровнями. Я хочу корону. 👑",
        ])
    }

    private static func lines(_ en: [String], _ uk: [String], _ ru: [String]) -> [String] {
        switch L10n.lang {
        case .en: return en
        case .uk: return uk
        case .ru: return ru
        }
    }

    private static func pick(_ lines: [String], _ now: Date, _ nonce: Int) -> String {
        let slot = Int(now.timeIntervalSince1970 / 40) + nonce
        return lines[((slot % lines.count) + lines.count) % lines.count]
    }
}
