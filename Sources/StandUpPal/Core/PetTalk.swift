import Foundation

/// What the pet says in its speech bubble. Lines rotate slowly and on every tap.
@MainActor
enum PetTalk {
    static func line(store: AppStore, scheduler: Scheduler, now: Date) -> String {
        let s = store.settings
        let nonce = store.talkNonce

        if store.showWelcome {
            return "Hi, I'm \(s.petName)! 👋 I'll nudge you to stand up \(s.leadMinutes) min before every hour. Right-click me in the menu bar for quick options."
        }
        if scheduler.active != nil {
            return "It's time! Up, up, up! 🧍"
        }
        if let reason = scheduler.holdReason, !scheduler.queue.isEmpty {
            return "Shh… your \(reason) is on. I'll wave as soon as your call ends. 🤫"
        }
        if let reaction = store.reaction, store.reactionUntil > now {
            switch reaction {
            case .celebrate:
                return pick(["WOOO! That was awesome! 🎉", "Look at you go! My hero. 💪", "Stretchy legend status: confirmed. ✨"], now, nonce)
            case .happy:
                return pick(["Hehe, that tickles! 💚", "Yay! Thank you! ✨", "You're the best human. 🥰", "Boop! 💫"], now, nonce)
            case .sad:
                return pick(["Aww… okay. Next time? 🥺", "My tiny legs were ready… 😔", "I'll be here. Still stretching. Alone."], now, nonce)
            default:
                break
            }
        }
        if scheduler.isPaused(now), let until = store.runtime.pausedUntil {
            return "Taking a break from nagging until \(Clock.time(until)). Zzz… 😴"
        }

        let done = store.today.standupsDone
        if !scheduler.isWorkingTime(now) {
            let isWorkDay = s.workDays.contains(Clock.weekday(now))
            if isWorkDay, Clock.minuteOfDay(now) < s.workStartMinute, let next = scheduler.nextStandup {
                return "Good morning! ☀️ First stretch at \(Clock.time(next))."
            }
            if done > 0 {
                return "Off the clock! \(done) stand-up\(done == 1 ? "" : "s") today. Proud of you. 🌙"
            }
            return pick(["Zzz… it's not work o'clock. 💤", "Off the clock! Go do something fun. 🌙", "Resting my tiny legs for the next work day."], now, nonce)
        }

        if let next = scheduler.nextStandup {
            let seconds = next.timeIntervalSince(now)
            if seconds <= 5 * 60 {
                return "Stretch time in \(Clock.minutesLabel(seconds)). Get those legs ready! 🦵"
            }
        }
        if store.pet.happiness < 30 {
            return pick(["I miss our stretches… maybe the next one? 🥺", "Feeling a bit stiff. Wanna stretch together?"], now, nonce)
        }
        if done >= s.dailyGoal {
            return pick(["Daily goal smashed! You're a legend. 🏆", "\(done) stand-ups today! My legs are proud of your legs."], now, nonce)
        }
        return pick(idleLines, now, nonce)
    }

    private static let idleLines = [
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
    ]

    private static func pick(_ lines: [String], _ now: Date, _ nonce: Int) -> String {
        let slot = Int(now.timeIntervalSince1970 / 40) + nonce
        return lines[((slot % lines.count) + lines.count) % lines.count]
    }
}
