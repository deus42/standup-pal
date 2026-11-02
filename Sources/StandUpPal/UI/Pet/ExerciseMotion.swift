import Foundation

/// How the pet demonstrates an exercise during a warm-up.
enum ExerciseMotion: String, CaseIterable {
    case reach, march, neck, shoulders, armCircles, chest, twist, sideBend, hips, calves, squat, hinge, wrists, shake
    case eyes, breathe, chinTuck, bladeSqueeze, backBend, ankles, wallPush, rest, generic
    /// Not an exercise: the desktop pet strolling.
    case walk

    init(exerciseID: String) {
        switch exerciseID {
        case "reach": self = .reach
        case "march": self = .march
        case "neck": self = .neck
        case "shoulders": self = .shoulders
        case "arms": self = .armCircles
        case "chest": self = .chest
        case "twist": self = .twist
        case "sidebend": self = .sideBend
        case "hips": self = .hips
        case "calves": self = .calves
        case "squats": self = .squat
        case "hamstrings": self = .hinge
        case "wrists": self = .wrists
        case "shake": self = .shake
        case "eyes": self = .eyes
        case "breathe": self = .breathe
        case "chintuck": self = .chinTuck
        case "blades": self = .bladeSqueeze
        case "backbend": self = .backBend
        case "ankles": self = .ankles
        case "deskpushups": self = .wallPush
        case "rest": self = .rest
        default: self = .generic
        }
    }
}
