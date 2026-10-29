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
    /// Built-in exercises, in the current language.
    static var builtIn: [Exercise] {
        [
            Exercise(id: "reach", name: tr("Reach for the sky", "Тягнися до неба", "Тянись к небу"), emoji: "🙆",
                     instructions: tr("Stand tall, interlace your fingers and push your palms up to the ceiling. Breathe deep and grow an inch.",
                                      "Стань рівно, переплети пальці й тягни долоні до стелі. Глибокий вдих — і ти вже трохи вищий.",
                                      "Встань ровно, сцепи пальцы в замок и тяни ладони к потолку. Глубокий вдох — и ты уже чуть выше."),
                     seconds: 30, slot: .opener),
            Exercise(id: "march", name: tr("March in place", "Марш на місці", "Марш на месте"), emoji: "🥁",
                     instructions: tr("Lift your knees, swing your arms. A tiny parade for one.",
                                      "Піднімай коліна, махай руками. Маленький парад для однієї людини.",
                                      "Поднимай колени, маши руками. Маленький парад для одного человека."),
                     seconds: 30, slot: .opener),
            Exercise(id: "neck", name: tr("Neck half-circles", "Півкола шиєю", "Полукруги шеей"), emoji: "🦒",
                     instructions: tr("Drop one ear towards your shoulder, then roll your chin slowly across your chest to the other side. Gentle, no full circles.",
                                      "Нахили вухо до плеча, потім повільно перекоти підборіддя по грудях до іншого боку. Ніжно, без повних кіл.",
                                      "Наклони ухо к плечу, затем медленно перекати подбородок по груди к другой стороне. Мягко, без полных кругов."),
                     seconds: 30),
            Exercise(id: "shoulders", name: tr("Shoulder rolls", "Кола плечима", "Круги плечами"), emoji: "🤷",
                     instructions: tr("Lift your shoulders up to your ears, roll them back and down. Ten times backwards, then forwards.",
                                      "Підніми плечі до вух, відведи назад і опусти. Десять разів назад, потім уперед.",
                                      "Подними плечи к ушам, отведи назад и опусти. Десять раз назад, потом вперёд."),
                     seconds: 30),
            Exercise(id: "arms", name: tr("Arm circles", "Кола руками", "Круги руками"), emoji: "🌀",
                     instructions: tr("Arms out to the sides. Small circles that grow bigger, then reverse direction.",
                                      "Руки в сторони. Маленькі кола, що поступово більшають, потім у зворотний бік.",
                                      "Руки в стороны. Маленькие круги, которые постепенно растут, потом в обратную сторону."),
                     seconds: 30),
            Exercise(id: "chest", name: tr("Chest opener", "Розкрий груди", "Раскрой грудь"), emoji: "🦅",
                     instructions: tr("Clasp your hands behind your back, straighten your arms and lift gently. Undo that keyboard hunch.",
                                      "Зчепи руки за спиною, випрями їх і м'яко підніми. Прощавай, сутулість за клавіатурою.",
                                      "Сцепи руки за спиной, выпрями их и мягко подними. Прощай, сутулость за клавиатурой."),
                     seconds: 30),
            Exercise(id: "twist", name: tr("Torso twists", "Скручування корпусу", "Скручивания корпуса"), emoji: "🌪️",
                     instructions: tr("Feet hip-width apart, hands on hips. Rotate gently left and right and let your gaze follow.",
                                      "Ноги на ширині стегон, руки на поясі. М'яко повертайся вліво й управо, погляд — слідом.",
                                      "Ноги на ширине бёдер, руки на поясе. Мягко поворачивайся влево и вправо, взгляд — следом."),
                     seconds: 30),
            Exercise(id: "sidebend", name: tr("Side bends", "Нахили в сторони", "Наклоны в стороны"), emoji: "🌴",
                     instructions: tr("Reach one arm overhead and lean to the other side like a palm tree in the breeze. Switch halfway.",
                                      "Підніми руку над головою й нахилися в інший бік, як пальма на вітрі. На половині зміни бік.",
                                      "Подними руку над головой и наклонись в другую сторону, как пальма на ветру. На половине смени сторону."),
                     seconds: 30),
            Exercise(id: "hips", name: tr("Hip circles", "Кола стегнами", "Круги бёдрами"), emoji: "💃",
                     instructions: tr("Hands on hips, draw big slow circles with your hips. Switch direction halfway.",
                                      "Руки на поясі, малюй стегнами великі повільні кола. На половині зміни напрямок.",
                                      "Руки на поясе, рисуй бёдрами большие медленные круги. На половине смени направление."),
                     seconds: 30),
            Exercise(id: "calves", name: tr("Calf raises", "Підйоми на носки", "Подъёмы на носки"), emoji: "🩰",
                     instructions: tr("Rise up onto your toes, pause, lower slowly. Hold the desk for balance if you like.",
                                      "Піднімися на носки, затримайся, повільно опустися. Можна триматися за стіл.",
                                      "Поднимись на носки, задержись, медленно опустись. Можно держаться за стол."),
                     seconds: 30),
            Exercise(id: "squats", name: tr("Chair squats", "Присідання до стільця", "Приседания к стулу"), emoji: "🪑",
                     instructions: tr("Feet shoulder-width apart. Sit back towards your chair until you almost touch it, then stand. Slow and steady.",
                                      "Ноги на ширині плечей. Сідай назад до стільця, майже торкнися — і вставай. Повільно й рівно.",
                                      "Ноги на ширине плеч. Садись назад к стулу, почти коснись — и вставай. Медленно и ровно."),
                     seconds: 40),
            Exercise(id: "hamstrings", name: tr("Hamstring hang", "Нахил униз", "Наклон вниз"), emoji: "🤸",
                     instructions: tr("Soft knees, hinge at the hips and let your hands slide down towards your shins. Hang loose and breathe.",
                                      "М'які коліна, нахилися від стегон, руки ковзають до гомілок. Розслабся й дихай.",
                                      "Мягкие колени, наклонись от бёдер, руки скользят к голеням. Расслабься и дыши."),
                     seconds: 30),
            Exercise(id: "wrists", name: tr("Wrist & finger stretch", "Розтяжка зап'ястків", "Растяжка запястий"), emoji: "🙌",
                     instructions: tr("Arm out, palm up, gently pull your fingers back with the other hand. Then palm down. Switch arms halfway.",
                                      "Рука вперед долонею вгору, другою рукою м'яко відтягни пальці. Потім долонею вниз. На половині зміни руку.",
                                      "Рука вперёд ладонью вверх, другой рукой мягко оттяни пальцы. Потом ладонью вниз. На половине смени руку."),
                     seconds: 30),
            Exercise(id: "shake", name: tr("Shake it out", "Струси напругу", "Стряхни напряжение"), emoji: "🐶",
                     instructions: tr("Shake your hands, arms and legs loose, like a dog fresh out of a lake.",
                                      "Струси кисті, руки й ноги, як песик, що щойно виліз з озера.",
                                      "Стряхни кисти, руки и ноги, как пёсик, только что вылезший из озера."),
                     seconds: 20),
            Exercise(id: "eyes", name: tr("Eye break", "Перерва для очей", "Перерыв для глаз"), emoji: "👀",
                     instructions: tr("Look at something at least six metres away. Let your eyes relax and blink slowly.",
                                      "Подивися на щось щонайменше за шість метрів. Дай очам розслабитися й повільно покліпай.",
                                      "Посмотри на что-нибудь минимум в шести метрах. Дай глазам расслабиться и медленно поморгай."),
                     seconds: 20, slot: .closer),
            Exercise(id: "breathe", name: tr("Deep breaths", "Глибоке дихання", "Глубокое дыхание"), emoji: "🌬️",
                     instructions: tr("Breathe in for 4, hold for 4, out for 6. Shoulders down, jaw loose.",
                                      "Вдих на 4, затримка на 4, видих на 6. Плечі вниз, щелепа розслаблена.",
                                      "Вдох на 4, задержка на 4, выдох на 6. Плечи вниз, челюсть расслаблена."),
                     seconds: 30, slot: .closer),
        ]
    }

    static func all(_ settings: AppSettings) -> [Exercise] {
        builtIn + settings.customExercises
    }

    static let maxCustom = 6

    /// A fresh random routine that fits the requested length: an opener, a shuffled
    /// middle (custom exercises first), and a calm closer.
    static func routine(totalSeconds: Int, settings: AppSettings) -> [Exercise] {
        let library = Self.builtIn
        var pool = (library + settings.customExercises).filter { !settings.disabledExerciseIDs.contains($0.id) }
        if pool.isEmpty { pool = library }

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
