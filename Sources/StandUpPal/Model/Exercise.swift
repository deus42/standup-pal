import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    enum Slot: String, Codable {
        case opener, any, closer
    }

    var id: String
    var name: String
    var emoji: String
    var instructions: String
    var seconds: Int
    var slot: Slot = .any
    var isCustom = false
}

extension Exercise {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.value(.id, UUID().uuidString)
        name = c.value(.name, "Exercise")
        emoji = c.value(.emoji, "⭐️")
        instructions = c.value(.instructions, "")
        seconds = c.value(.seconds, 30)
        slot = c.value(.slot, .any)
        isCustom = c.value(.isCustom, false)
    }
}

enum ExerciseLibrary {
    static let builtIn: [Exercise] = [
        Exercise(id: "reach", name: "Reach for the sky", emoji: "🙆",
                 instructions: "Stand tall, interlace your fingers and push your palms up to the ceiling. Breathe deep and grow an inch.",
                 seconds: 30, slot: .opener),
        Exercise(id: "march", name: "March in place", emoji: "🥁",
                 instructions: "Lift your knees, swing your arms. A tiny parade for one.",
                 seconds: 30, slot: .opener),
        Exercise(id: "neck", name: "Neck half-circles", emoji: "🦒",
                 instructions: "Drop one ear towards your shoulder, then roll your chin slowly across your chest to the other side. Gentle, no full circles.",
                 seconds: 30),
        Exercise(id: "shoulders", name: "Shoulder rolls", emoji: "🤷",
                 instructions: "Lift your shoulders up to your ears, roll them back and down. Ten times backwards, then forwards.",
                 seconds: 30),
        Exercise(id: "arms", name: "Arm circles", emoji: "🌀",
                 instructions: "Arms out to the sides. Small circles that grow bigger, then reverse direction.",
                 seconds: 30),
        Exercise(id: "chest", name: "Chest opener", emoji: "🦅",
                 instructions: "Clasp your hands behind your back, straighten your arms and lift gently. Undo that keyboard hunch.",
                 seconds: 30),
        Exercise(id: "twist", name: "Torso twists", emoji: "🌪️",
                 instructions: "Feet hip-width apart, hands on hips. Rotate gently left and right and let your gaze follow.",
                 seconds: 30),
        Exercise(id: "sidebend", name: "Side bends", emoji: "🌴",
                 instructions: "Reach one arm overhead and lean to the other side like a palm tree in the breeze. Switch halfway.",
                 seconds: 30),
        Exercise(id: "hips", name: "Hip circles", emoji: "💃",
                 instructions: "Hands on hips, draw big slow circles with your hips. Switch direction halfway.",
                 seconds: 30),
        Exercise(id: "calves", name: "Calf raises", emoji: "🩰",
                 instructions: "Rise up onto your toes, pause, lower slowly. Hold the desk for balance if you like.",
                 seconds: 30),
        Exercise(id: "squats", name: "Chair squats", emoji: "🪑",
                 instructions: "Feet shoulder-width apart. Sit back towards your chair until you almost touch it, then stand. Slow and steady.",
                 seconds: 40),
        Exercise(id: "hamstrings", name: "Hamstring hang", emoji: "🤸",
                 instructions: "Soft knees, hinge at the hips and let your hands slide down towards your shins. Hang loose and breathe.",
                 seconds: 30),
        Exercise(id: "wrists", name: "Wrist & finger stretch", emoji: "🙌",
                 instructions: "Arm out, palm up, gently pull your fingers back with the other hand. Then palm down. Switch arms halfway.",
                 seconds: 30),
        Exercise(id: "shake", name: "Shake it out", emoji: "🐶",
                 instructions: "Shake your hands, arms and legs loose, like a dog fresh out of a lake.",
                 seconds: 20),
        Exercise(id: "eyes", name: "Eye break", emoji: "👀",
                 instructions: "Look at something at least six metres away. Let your eyes relax and blink slowly.",
                 seconds: 20, slot: .closer),
        Exercise(id: "breathe", name: "Deep breaths", emoji: "🌬️",
                 instructions: "Breathe in for 4, hold for 4, out for 6. Shoulders down, jaw loose.",
                 seconds: 30, slot: .closer),
    ]

    static func all(_ settings: AppSettings) -> [Exercise] {
        builtIn + settings.customExercises
    }

    /// A fresh random routine that fits the requested length: an opener, a shuffled
    /// middle (custom exercises first), and a calm closer.
    static func routine(totalSeconds: Int, settings: AppSettings) -> [Exercise] {
        var pool = all(settings).filter { !settings.disabledExerciseIDs.contains($0.id) }
        if pool.isEmpty { pool = builtIn }

        var result: [Exercise] = []
        var used = Set<String>()
        var budget = totalSeconds

        if let opener = pool.filter({ $0.slot == .opener }).randomElement() {
            result.append(opener)
            used.insert(opener.id)
            budget -= opener.seconds
        }

        let closer = pool.filter { $0.slot == .closer && !used.contains($0.id) }.randomElement()
        if let closer {
            used.insert(closer.id)
            budget -= closer.seconds
        }

        let shuffled = pool.filter { !used.contains($0.id) }.shuffled()
        let middle = shuffled.filter(\.isCustom) + shuffled.filter { !$0.isCustom }
        for exercise in middle where budget >= 15 && exercise.seconds <= budget + 5 {
            result.append(exercise)
            budget -= exercise.seconds
        }

        if let closer { result.append(closer) }
        if result.isEmpty, let first = pool.first { result = [first] }
        return result
    }
}
