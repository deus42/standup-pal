import Foundation
import Testing
@testable import StandUpPal

@Suite("Programs and motions")
struct ProgramTests {
    @Test func everyBuiltInExerciseHasItsOwnMotion() {
        for exercise in ExerciseLibrary.builtIn {
            #expect(ExerciseMotion(exerciseID: exercise.id) != .generic, "\(exercise.id) has no motion")
        }
        #expect(ExerciseMotion(exerciseID: "custom-123") == .generic)
        #expect(Set(ExerciseLibrary.builtIn.map(\.id)).count == ExerciseLibrary.builtIn.count)
    }

    @Test func programsExpandSetsWithRestsBetween() {
        let program = ReminderProgram(steps: [ProgramStep(exerciseID: "neck", seconds: 20),
                                              ProgramStep(exerciseID: "chintuck", seconds: 25)],
                                      sets: 3, restSeconds: 15)
        let routine = ExerciseLibrary.routine(for: program, settings: AppSettings())
        #expect(routine.map(\.id) == ["neck", "chintuck", "rest", "neck", "chintuck", "rest", "neck", "chintuck"])
        #expect(routine.first?.seconds == 20 && routine[1].seconds == 25 && routine[2].seconds == 15)
        #expect(program.totalSeconds == 45 * 3 + 15 * 2)
        #expect(routine.reduce(0) { $0 + $1.seconds } == program.totalSeconds)
    }

    @Test func noRestStepsWhenRestIsZeroAndMissingExercisesAreSkipped() {
        let program = ReminderProgram(steps: [ProgramStep(exerciseID: "wrists", seconds: 30),
                                              ProgramStep(exerciseID: "custom-deleted", seconds: 30)],
                                      sets: 2, restSeconds: 0)
        #expect(ExerciseLibrary.routine(for: program, settings: AppSettings()).map(\.id) == ["wrists", "wrists"])
        #expect(ExerciseLibrary.routine(for: ReminderProgram(), settings: AppSettings()).isEmpty)
    }

    @Test func everyPresetUsesRealExercises() {
        for preset in ProgramPreset.allCases {
            let program = preset.program
            #expect(!program.steps.isEmpty)
            #expect(ExerciseLibrary.routine(for: program, settings: AppSettings()).filter { $0.id != "rest" }.count
                    == program.steps.count * program.sets, "\(preset.rawValue)")
        }
    }

    @Test func remindersWithoutAProgramStillDecode() throws {
        let json = #"{"title":"Фізіотерапія","emoji":"🧘","times":[600]}"#
        let reminder = try JSONDecoder().decode(CustomReminder.self, from: Data(json.utf8))
        #expect(reminder.program == nil && !reminder.hasProgram)
        var withProgram = reminder
        withProgram.program = ProgramPreset.neckShoulders.program
        let back = try JSONDecoder().decode(CustomReminder.self, from: try JSONEncoder().encode(withProgram))
        #expect(back.program == withProgram.program && back.hasProgram)
    }

    @MainActor
    @Test func finishingAReminderProgramCountsAsThatExtra() {
        let store = AppStore.shared
        store.settings.soundEnabled = false
        let occ = Occurrence(id: "extra-program-\(UUID().uuidString)", kind: .custom(UUID()), scheduled: Date(), due: Date())
        let standups = store.today.standupsDone
        let extras = store.today.extrasDone
        let xp = store.pet.xp
        #expect(Scheduler.shared.completeWarmUp(for: occ, seconds: 300, full: true) == 20)
        #expect(store.today.standupsDone == standups)
        #expect(store.today.extrasDone == extras + 1)
        #expect(store.pet.xp == xp + 20)
    }
}
