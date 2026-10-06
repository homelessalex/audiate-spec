import Foundation
import Testing
@testable import AudiateCore

/// docs/06 M2 acceptance: a new user can complete U1 AO → VA across multiple days — and then the
/// notation levels (SA, PS, CS) without seeing notation before AO is passed.
@Suite("Progress simulation")
struct ProgressSimulationTests {
    @Test func perfectLearnerCompletesU1AuralThenVerbalOverSeveralDays() {
        let curriculum = Fixtures.curriculum, library = Fixtures.library, calendar = Fixtures.calendar
        let planner = SessionPlanner(curriculum: curriculum, library: library, calendar: calendar)
        var progress = LearnerProgress()
        var rng = SeededRandomNumberGenerator(seed: 3)
        var passedOn: [LevelKey: Int] = [:]

        for day in 0..<14 {
            // several sessions a day, as the flow chains them, until the day's work runs out
            for session in 0..<40 {
                let plan = planner.plan(progress, date: Fixtures.day(day), using: &rng)
                if plan.isEmpty { break }
                #expect(session < 39, "day \(day): planning never runs dry")
                for step in plan.steps {
                    // inference levels work on unfamiliar patterns only
                    if case .echo(let b) = step {
                        for item in b.items where item.generated != nil { #expect(!library.isFamiliar(item.generated!.shape)) }
                    }
                    // sound before sight: notation only for units that already passed AO by ear
                    for unit in StepAttempts.notationUnits(step) {
                        #expect(Gate.canShowNotation(unitID: unit, passed: progress.passed), "day \(day): notation of \(unit)")
                    }
                    for (k, attempt) in StepAttempts.perfect(step, at: Fixtures.day(day).addingTimeInterval(Double(session * 600))).enumerated() {
                        let timed = Attempt(date: attempt.date.addingTimeInterval(Double(k)), unitID: attempt.unitID, level: attempt.level,
                                            patternID: attempt.patternID, exercise: attempt.exercise, mode: attempt.mode,
                                            passed: true, accuracy: 1)
                        for key in progress.record(timed, curriculum: curriculum, library: library, calendar: calendar) {
                            passedOn[key] = day
                        }
                    }
                }
            }
        }

        let ao = LevelKey(unitID: "U1", level: .aural), va = LevelKey(unitID: "U1", level: .verbal)
        let aoDay = try! #require(passedOn[ao])
        let vaDay = try! #require(passedOn[va])
        #expect(aoDay >= 1, "mastery needs two calendar days")
        #expect(vaDay > aoDay)
        #expect(vaDay <= 7)
        for level in [SkillLevel.symbolic, .partialSynthesis, .compositeSynthesis] {
            #expect(passedOn[LevelKey(unitID: "U1", level: level)] != nil, "U1 \(level.code) passes within two weeks")
        }
        #expect(passedOn[LevelKey(unitID: "U2", level: .verbal)] != nil, "U2 runs in parallel with U1")
        #expect(Gate.isUnlocked(LevelKey(unitID: "U3", level: .aural), curriculum: curriculum, passed: progress.passed))
        #expect(Gate.isUnlocked(LevelKey(unitID: "U1", level: .symbolic), curriculum: curriculum, passed: progress.passed))
    }
}
