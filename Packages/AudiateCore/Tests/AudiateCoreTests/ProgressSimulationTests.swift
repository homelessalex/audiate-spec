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
                case .echo(let block):
                    #expect(block.items.allSatisfy { $0.level == .aural || $0.level == .verbal })
                    block.items.forEach { record($0, .echo, block.mode) }
                case .nameSyllables(let q):
                    #expect(q.item.level == .verbal)
                    record(q.item, .nameSyllables, q.mode)
                case .read(let block):
                    // sound before sight, per pattern: notation only after the pattern's ear teaching
                    for item in block.items {
                        #expect(progress.hasHeard(patternID: item.patternID), "day \(day): \(item.patternID) read before heard")
                    }
                    block.items.forEach { record($0, .read, block.mode) }
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
        #expect(passedOn[LevelKey(unitID: "U1", level: .symbolic)] != nil, "reading U1 is learned alongside the ear")
    }
}
