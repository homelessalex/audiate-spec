import Foundation
import Testing
@testable import AudiateCore

@Suite("Improvisation grader (E8)")
struct ImprovGraderTests {
    let prompt = Fixtures.pattern("D-MM-02") // 12 12 24 → onsets 0 12 24
    let tempo = Tempo(bpm: 80)                // tick = 1/32 s
    let unlocked: Set<ContentKind> = [.macroMicro, .division]

    func taps(_ ticks: [Double], scale: Double = 1, offset: Double = 0) -> [Double] {
        ticks.map { 10 + offset + $0 / 32 * scale }
    }

    func grade(_ t: [Double]) -> ImprovGrade {
        ImprovGrader.grade(taps: t, prompt: prompt, downbeat: 10, tempo: tempo, unlocked: unlocked)
    }

    @Test func aValidDifferentAnswerPasses() {
        let g = grade(taps([0, 6, 12, 24, 36]))
        #expect(g.passed)
        #expect(g.quantizedOnsets == [0, 6, 12, 24, 36])
    }

    @Test func anExactEchoIsRejected() {
        #expect(grade(taps([0, 12, 24])).problems == [.sameAsPrompt])
    }

    @Test func offGridTooFewAndDrift() {
        #expect(grade(taps([0, 3, 24, 36])).problems.contains(.offGrid))                       // a quarter of a beat off
        #expect(grade(taps([0])).problems.contains(.tooFew))
        // 15 % slower within one measure: taps land between grid points — rejected (as off-grid or drift)
        #expect(!grade(taps([0, 12, 24, 36], scale: 1.15)).passed)
        #expect(grade(taps([0, 12, 36], scale: 1.04)).passed)                                    // a little slower is fine
        #expect(grade(taps([0, 12, 36], offset: 0.02)).passed)                                 // a steady small offset is fine
    }

    @Test func gridFollowsUnlockedContent() {
        let duple = prompt.meter
        #expect(ImprovGrader.gridTicks(duple, unlocked: [.macroMicro]) == [0, 12, 24, 36])
        #expect(ImprovGrader.gridTicks(duple, unlocked: [.macroMicro, .division]).count == 8)
        let combined = Fixtures.library.meters["usual_combined"]!
        #expect(ImprovGrader.gridTicks(combined, unlocked: [.macroMicro, .combined]) == [0, 8, 12, 16, 24, 32, 36, 40])
    }
}

@Suite("Inference levels in the plan")
struct InferencePlanTests {
    let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)

    /// U1–U3 through VA and SA (so GA/GV open for U1 and U2, and divisions are known).
    var progress: LearnerProgress {
        var p = LearnerProgress()
        for unit in ["U1", "U2", "U3"] {
            for level in [SkillLevel.aural, .verbal, .symbolic] {
                for id in Fixtures.curriculum.patterns(of: Fixtures.curriculum.unit(id: unit)!, in: Fixtures.library).map(\.id) {
                    for day in 0..<2 {
                        p.record(Attempt(date: Fixtures.day(day), unitID: unit, level: level, patternID: id,
                                         exercise: level == .symbolic ? .read : .echo, mode: .evaluation, passed: true, accuracy: 1),
                                 curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)
                    }
                }
            }
        }
        return p
    }

    @Test func generalizationUsesUnfamiliarPatternsAtVariedTempos() {
        let p = progress
        #expect(Gate.isUnlocked(LevelKey(unitID: "U1", level: .generalizationAural), curriculum: Fixtures.curriculum, passed: p.passed))
        var rng = SeededRandomNumberGenerator(seed: 9)
        let plan = planner.plan(p, date: Fixtures.day(5), using: &rng)
        let gaEchoes = plan.steps.compactMap { if case .echo(let e) = $0, e.items.first?.level == .generalizationAural { e } else { nil } }
        #expect(!gaEchoes.isEmpty)
        for e in gaEchoes {
            #expect(e.items.allSatisfy { $0.generated != nil && !Fixtures.library.isFamiliar($0.generated!.shape) })
            #expect(TempoPolicy.range(for: Fixtures.library.meters[e.meterID]!).contains(e.tempo.bpm))
            #expect(e.clickStage == .c && !e.showNotation)
        }
        #expect(plan.steps.contains { if case .sameOrDifferent = $0 { true } else { false } })
        let gv = plan.steps.compactMap { if case .nameNotation(let q) = $0, q.item.level == .generalizationVerbal { q } else { nil } }
        #expect(!gv.isEmpty)
        #expect(gv.allSatisfy { $0.options[$0.correctIndex].shape == $0.item.generated?.shape })
    }

    @Test func flowKindsForSameDifferentAnswerAndCompose() throws {
        let gen = try PatternGenerator(library: Fixtures.library).generate(meter: Fixtures.library.meters["usual_duple"]!,
                                                                           unlocked: [.macroMicro, .division],
                                                                           using: &SeededRandomNumberGeneratorBox.rng)
        let steps: [SessionStep] = [
            .sameOrDifferent(SameOrDifferentSpec(unitID: "U1", first: gen, second: gen, tempo: Tempo(bpm: 80))),
            .answerDifferently(AnswerDifferentlySpec(unitID: "U1", prompt: gen, tempo: Tempo(bpm: 80), unlocked: [.macroMicro])),
            .compose(ComposeSpec(unitID: "U1", meterID: "usual_duple", palette: [], tempo: Tempo(bpm: 80))),
        ]
        let e4 = FlowSequencer(steps: steps, library: Fixtures.library)
        #expect(e4.measures.map(\.role) == [.countIn, .prompt, .prompt, .leadIn])
        #expect(e4.attempts[0].kind.awaitsInput && e4.attempts[0].pattern == gen)
        let e8 = FlowSequencer(steps: steps, library: Fixtures.library, from: .init(step: 1, item: 0, attempt: 1))
        #expect(e8.measures.map(\.role) == [.countIn, .prompt, .hold, .response, .leadIn])
        let e9 = FlowSequencer(steps: steps, library: Fixtures.library, from: .init(step: 2, item: 0, attempt: 1))
        #expect(e9.attempts[0].kind == .compose && e9.endTime == 0)
    }
}

/// A shared seeded generator for one-off generation in tests.
enum SeededRandomNumberGeneratorBox {
    nonisolated(unsafe) static var rng = SeededRandomNumberGenerator(seed: 11)
}
