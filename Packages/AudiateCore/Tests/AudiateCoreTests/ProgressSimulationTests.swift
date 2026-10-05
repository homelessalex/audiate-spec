import Foundation
import Testing
@testable import AudiateCore

/// docs/06 M2 acceptance: a new user can complete U1 AO → VA across multiple days.
@Suite("Progress simulation")
struct ProgressSimulationTests {
    @Test func perfectLearnerCompletesU1AuralThenVerbalOverSeveralDays() {
        let curriculum = Fixtures.curriculum, library = Fixtures.library, calendar = Fixtures.calendar
        let planner = SessionPlanner(curriculum: curriculum, library: library)
        var progress = LearnerProgress()
        var rng = SeededRandomNumberGenerator(seed: 3)
        var passedOn: [LevelKey: Int] = [:]

        for day in 0..<10 {
            let plan = planner.plan(progress, date: Fixtures.day(day), using: &rng)
            var minute = 0
            func record(_ item: PlannedItem, _ exercise: ExerciseKind, _ mode: PracticeMode) {
                minute += 1
                let date = Fixtures.day(day).addingTimeInterval(Double(minute) * 60)
                let attempt = Attempt(date: date, unitID: item.unitID, level: item.level, patternID: item.patternID,
                                      exercise: exercise, mode: mode, passed: true, accuracy: 1)
                for key in progress.record(attempt, curriculum: curriculum, library: library, calendar: calendar) {
                    passedOn[key] = day
                }
            }
            for step in plan.steps {
                switch step {
                case .echo(let block): block.items.forEach { record($0, .echo, block.mode) }
                case .nameSyllables(let q): record(q.item, .nameSyllables, q.mode)
                }
                // nothing beyond the implemented levels is ever scheduled
                switch step {
                case .echo(let b): #expect(b.items.allSatisfy { SessionPlanner.implementedLevels.contains($0.level) })
                case .nameSyllables(let q): #expect(q.item.level == .verbal)
                }
            }
        }

        let ao = LevelKey(unitID: "U1", level: .aural), va = LevelKey(unitID: "U1", level: .verbal)
        let aoDay = try! #require(passedOn[ao])
        let vaDay = try! #require(passedOn[va])
        #expect(aoDay >= 1, "mastery needs two calendar days")
        #expect(vaDay > aoDay)
        #expect(vaDay <= 7)
        #expect(Gate.isUnlocked(LevelKey(unitID: "U2", level: .aural), curriculum: curriculum, passed: progress.passed))
        #expect(!Gate.canShowNotation(unitID: "U1", curriculum: curriculum, passed: progress.passed))
    }
}
