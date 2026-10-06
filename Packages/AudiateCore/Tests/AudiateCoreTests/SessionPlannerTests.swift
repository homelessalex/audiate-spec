import Foundation
import Testing
@testable import AudiateCore

@Suite("SessionPlanner")
struct SessionPlannerTests {
    let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)
    let calendar = Fixtures.calendar

    func plan(_ progress: LearnerProgress, day: Int, seed: UInt64 = 1) -> SessionPlan {
        var rng = SeededRandomNumberGenerator(seed: seed)
        return planner.plan(progress, date: Fixtures.day(day), using: &rng)
    }

    func echoes(_ plan: SessionPlan) -> [EchoBlockSpec] {
        plan.steps.compactMap { if case .echo(let e) = $0 { e } else { nil } }
    }

    func reads(_ plan: SessionPlan) -> [ReadBlockSpec] {
        plan.steps.compactMap { if case .read(let r) = $0 { r } else { nil } }
    }

    /// Sessions chain into one flow: replanning on the same day must run dry, not loop forever.
    @Test func sameDayReplanningRunsDry() {
        var progress = LearnerProgress()
        var rng = SeededRandomNumberGenerator(seed: 5)
        var sessions = 0
        while sessions < 20 {
            let p = planner.plan(progress, date: Fixtures.day(0), using: &rng)
            if p.isEmpty { break }
            sessions += 1
            for step in p.steps {
                for attempt in StepAttempts.perfect(step, at: Fixtures.day(0)) {
                    progress.record(attempt, curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
                }
            }
        }
        #expect(sessions < 20)
        // up to four new patterns a day per unit (U1 and U2 in parallel), each evaluated at most four times
        let evaluated = Dictionary(grouping: progress.attempts.filter { $0.mode == .evaluation && $0.patternID != nil },
                                   by: { $0.patternID! }).mapValues(\.count)
        #expect(evaluated.count == 2 * MasteryPolicy.maxNewPatternsPerDayPerUnit)
        #expect(evaluated.values.allSatisfy { $0 <= MasteryPolicy.maxEvaluationsPerPatternPerDay + MasteryPolicy.minBlockSize })
        // and the next day there is work again
        #expect(!planner.plan(progress, date: Fixtures.day(1), using: &rng).isEmpty)
    }

    @Test func freePracticeCoversTaughtPatternsAndNeverCounts() {
        var progress = LearnerProgress()
        var rng = SeededRandomNumberGenerator(seed: 2)
        #expect(planner.freePractice(progress, using: &rng).isEmpty) // nothing taught yet
        for id in ["D-MM-01", "T-MM-01"] {
            progress.record(Attempt(date: Fixtures.day(0), unitID: Fixtures.curriculum.unit(containing: id)!.id, level: .aural,
                                    patternID: id, exercise: .echo, mode: .teaching, passed: true, accuracy: 1),
                            curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        }
        let practice = planner.freePractice(progress, using: &rng)
        let blocks = echoes(practice)
        #expect(Set(blocks.flatMap(\.items).map(\.patternID)) == ["D-MM-01", "T-MM-01"])
        #expect(blocks.allSatisfy { $0.mode == .practice && !$0.showNotation }) // AO not passed: by ear only
        let before = progress
        progress.record(Attempt(date: Fixtures.day(0), unitID: "U1", level: .aural, patternID: "D-MM-01", exercise: .echo,
                                mode: .practice, passed: true, accuracy: 1),
                        curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        #expect(progress.items == before.items && progress.passedAt == before.passedAt)
    }

    @Test func noReadingWhileOnlyEarLevelsAreOpen() {
        #expect(reads(plan(LearnerProgress(), day: 0)).isEmpty)
    }

    @Test func taughtOnceCorrectOrAfterMaxAttempts() {
        var progress = LearnerProgress()
        func teach(_ id: String, passed: Bool) {
            progress.record(Attempt(date: Fixtures.day(0), unitID: "U1", level: .aural, patternID: id, exercise: .echo,
                                    mode: .teaching, passed: passed, accuracy: passed ? 1 : 0.5),
                            curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        }
        teach("D-MM-01", passed: false)
        #expect(!progress.isIntroduced(patternID: "D-MM-01", level: .aural))
        teach("D-MM-01", passed: true)
        #expect(progress.isIntroduced(patternID: "D-MM-01", level: .aural))
        for _ in 0..<MasteryPolicy.maxTeachingAttempts { teach("D-MM-02", passed: false) }
        #expect(progress.isIntroduced(patternID: "D-MM-02", level: .aural))
    }

    @Test func newLearnerStartsWithU1AuralTeaching() {
        let p = plan(LearnerProgress(), day: 0)
        #expect(p.frontiers == [LevelKey(unitID: "U1", level: .aural), LevelKey(unitID: "U2", level: .aural)])
        let blocks = echoes(p)
        let teaching = blocks.filter { $0.mode == .teaching }
        // U1 and U2 have four patterns each, all introduced on day one
        #expect(Dictionary(grouping: teaching, by: { $0.items[0].unitID }).mapValues(\.count) == ["U1": 4, "U2": 4])
        #expect(teaching.allSatisfy { $0.items.count == 1 }) // repeated until correct by the session runner
        #expect(teaching.allSatisfy { $0.clickStage == .a && !$0.showNotation })
        for b in teaching { #expect(b.tempo == TempoPolicy.teaching(for: Fixtures.library.meters[b.meterID]!)) }
        let evaluation = blocks.filter { $0.mode == .evaluation }
        #expect(!evaluation.isEmpty)
        for b in evaluation {
            #expect(b.clickStage == .b && !b.showNotation && b.tempo == .standard(for: Fixtures.library.meters[b.meterID]!))
        }
        // only the two taught patterns are evaluated
        let taught = Set(teaching.map(\.items[0].patternID))
        #expect(Set(evaluation.flatMap(\.items).map(\.patternID)) == taught)
        #expect(!p.steps.contains { if case .nameNotation = $0 { true } else { false } }) // no E2 at AO
    }

    @Test func blocksAreSameMeterAndAtLeastThree() {
        for day in 0..<3 {
            for block in echoes(plan(LearnerProgress(), day: day, seed: UInt64(day))) {
                let meters = Set(block.items.compactMap { Fixtures.library.pattern(id: $0.patternID)?.meter.id })
                #expect(meters == [block.meterID])
                if block.mode == .evaluation { #expect(block.items.count >= MasteryPolicy.minBlockSize) }
            }
        }
    }

    @Test func evaluationsPerPatternAreCapped() {
        let p = plan(LearnerProgress(), day: 0)
        let counts = Dictionary(grouping: echoes(p).filter { $0.mode == .evaluation }.flatMap(\.items), by: \.patternID).mapValues(\.count)
        #expect(counts.values.allSatisfy { $0 <= MasteryPolicy.maxEvaluationsPerPatternPerDay + MasteryPolicy.minBlockSize })
        #expect(p.estimatedSeconds <= planner.sessionSeconds + 60)
    }

    @Test func verbalLevelShowsNotationAndAddsWhichNotation() {
        var progress = LearnerProgress()
        let u1 = Fixtures.curriculum.patterns(of: Fixtures.curriculum.unit(id: "U1")!, in: Fixtures.library)
        for day in 0..<2 {
            for p in u1 {
                progress.record(Attempt(date: Fixtures.day(day), unitID: "U1", level: .aural, patternID: p.id, exercise: .echo,
                                        mode: .evaluation, passed: true, accuracy: 1),
                                curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
            }
        }
        #expect(progress.passed.contains(LevelKey(unitID: "U1", level: .aural)))
        let p = plan(progress, day: 3) // AO items from day 1 are in box 2 → due on day 3
        #expect(p.frontiers == [LevelKey(unitID: "U1", level: .verbal), LevelKey(unitID: "U2", level: .aural)])
        #expect(echoes(p).filter { $0.items[0].level == .verbal }.allSatisfy { $0.showNotation })
        #expect(echoes(p).filter { $0.items[0].level == .aural }.allSatisfy { !$0.showNotation })
        let questions = p.steps.compactMap { if case .nameNotation(let q) = $0 { q } else { nil } }
        #expect(!questions.isEmpty)
        for q in questions {
            #expect(q.options[q.correctIndex].shape == Fixtures.pattern(q.item.patternID).shape)
            #expect(Set(q.options.map(\.shape)).count == q.options.count)
        }
        // AO items due for review come first, in evaluation mode
        let review = echoes(p).prefix { $0.items[0].level == .aural }
        #expect(!review.isEmpty)
        #expect(review.allSatisfy { $0.mode == .evaluation && $0.items.allSatisfy { $0.purpose == .review } })
    }

    @Test func reviewGroupsByMeter() {
        var progress = LearnerProgress()
        // U3/U4 items (the frontiers are U1 and U2 AO, whose own items are practiced as new material, not review)
        for id in ["D-DV-01", "T-DV-01", "D-DV-02", "T-DV-02"] {
            let unit = Fixtures.curriculum.unit(containing: id)!.id
            progress.record(Attempt(date: Fixtures.day(0), unitID: unit, level: .aural, patternID: id, exercise: .echo,
                                    mode: .evaluation, passed: true, accuracy: 1),
                            curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        }
        let blocks = echoes(plan(progress, day: 1)).filter { $0.items.allSatisfy { $0.purpose != .new } }
        #expect(blocks.map(\.meterID).count == 2)
        #expect(Set(blocks.map(\.meterID)) == ["usual_duple", "usual_triple"])
    }
}
