import Foundation
import Testing
@testable import AudiateCore

@Suite("SessionPlanner")
struct SessionPlannerTests {
    let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library)
    let calendar = Fixtures.calendar

    func plan(_ progress: LearnerProgress, day: Int, seed: UInt64 = 1) -> SessionPlan {
        var rng = SeededRandomNumberGenerator(seed: seed)
        return planner.plan(progress, date: Fixtures.day(day), using: &rng)
    }

    func echoes(_ plan: SessionPlan) -> [EchoBlockSpec] {
        plan.steps.compactMap { if case .echo(let e) = $0 { e } else { nil } }
    }

    @Test func newLearnerStartsWithU1AuralTeaching() {
        let p = plan(LearnerProgress(), day: 0)
        #expect(p.frontier == LevelKey(unitID: "U1", level: .aural))
        let blocks = echoes(p)
        let teaching = blocks.filter { $0.mode == .teaching }
        #expect(teaching.count == MasteryPolicy.maxNewPatternsPerSessionPerUnit)
        #expect(teaching.allSatisfy { $0.items.count == MasteryPolicy.teachingEchoes && Set($0.items).count == 1 })
        #expect(teaching.allSatisfy { $0.clickStage == .a && !$0.showSyllables })
        let evaluation = blocks.filter { $0.mode == .evaluation }
        #expect(!evaluation.isEmpty)
        #expect(evaluation.allSatisfy { $0.clickStage == .b && !$0.showSyllables })
        // only the two taught patterns are evaluated
        let taught = Set(teaching.map(\.items[0].patternID))
        #expect(Set(evaluation.flatMap(\.items).map(\.patternID)) == taught)
        #expect(p.steps.allSatisfy { if case .echo = $0 { true } else { false } }) // no E2 at AO
    }

    @Test func blocksAreSameMeterAndAtLeastThree() {
        for day in 0..<3 {
            for block in echoes(plan(LearnerProgress(), day: day, seed: UInt64(day))) {
                let meters = Set(block.items.compactMap { Fixtures.library.pattern(id: $0.patternID)?.meter.id })
                #expect(meters == [block.meterID])
                #expect(block.items.count >= MasteryPolicy.minBlockSize)
            }
        }
    }

    @Test func evaluationsPerPatternAreCapped() {
        let p = plan(LearnerProgress(), day: 0)
        let counts = Dictionary(grouping: echoes(p).filter { $0.mode == .evaluation }.flatMap(\.items), by: \.patternID).mapValues(\.count)
        #expect(counts.values.allSatisfy { $0 <= SessionPlanner.maxEvaluationsPerPattern + MasteryPolicy.minBlockSize })
        #expect(p.estimatedSeconds <= planner.sessionSeconds + 60)
    }

    @Test func verbalLevelShowsSyllablesInTeachingAndAddsNameTheSyllables() {
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
        #expect(p.frontier == LevelKey(unitID: "U1", level: .verbal))
        #expect(echoes(p).filter { $0.mode == .teaching && $0.items[0].level == .verbal }.allSatisfy { $0.showSyllables })
        let questions = p.steps.compactMap { if case .nameSyllables(let q) = $0 { q } else { nil } }
        #expect(!questions.isEmpty)
        for q in questions {
            let line = try? SyllableDeriver().line(for: Fixtures.pattern(q.item.patternID))
            #expect(q.options[q.correctIndex] == line)
            #expect(Set(q.options).count == q.options.count)
        }
        // AO items due for review come first, in evaluation mode
        let review = echoes(p).prefix { $0.items[0].level == .aural }
        #expect(!review.isEmpty)
        #expect(review.allSatisfy { $0.mode == .evaluation && $0.items.allSatisfy { $0.purpose == .review } })
    }

    @Test func reviewGroupsByMeter() {
        var progress = LearnerProgress()
        // U2/U3 items (the frontier is U1 AO, whose own items are practiced as new material, not review)
        for id in ["D-DV-01", "T-MM-01", "D-DV-02", "T-MM-02"] {
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
