import Foundation
@testable import AudiateCore

/// What a learner who gets everything right records for one step (used by planner simulations).
enum StepAttempts {
    static func perfect(_ step: SessionStep, at date: Date) -> [Attempt] {
        func attempt(_ unitID: String, _ level: SkillLevel, _ patternID: String?, _ exercise: ExerciseKind, _ mode: PracticeMode) -> Attempt {
            Attempt(date: date, unitID: unitID, level: level, patternID: patternID, exercise: exercise, mode: mode, passed: true, accuracy: 1)
        }
        // generated patterns are graded per unit, not per pattern
        func id(_ item: PlannedItem) -> String? { item.generated == nil ? item.patternID : nil }
        switch step {
        case .echo(let b): return b.items.map { attempt($0.unitID, $0.level, id($0), b.exercise, b.mode) }
        case .read(let b): return b.items.map { attempt($0.unitID, $0.level, id($0), .read, b.mode) }
        case .nameNotation(let q): return [attempt(q.item.unitID, q.item.level, id(q.item), .nameNotation, q.mode)]
        case .dictation(let d): return [attempt(d.item.unitID, d.item.level, id(d.item), .write, d.mode)]
        case .sameOrDifferent(let s): return [attempt(s.unitID, .generalizationAural, nil, .sameOrDifferent, .evaluation)]
        case .answerDifferently(let a): return [attempt(a.unitID, .improvisationAural, nil, .answerDifferently, .evaluation)]
        case .compose(let c): return [attempt(c.unitID, .improvisationSymbolic, nil, .composeAndPerform, .evaluation)]
        case .whichMeter(let w): return [attempt(w.unitID, w.level, nil, .whichMeter, .evaluation)]
        case .meterFromNotation(let m): return [attempt(m.unitID, .compositeSynthesis, nil, .meterFromNotation, .evaluation)]
        case .readPhrase(let p):
            return p.phrases.map { _ in attempt(PhrasePolicy.unitID, .compositeSynthesis, PhraseLadder.patternID(rung: p.rung), .readPhrase, p.mode) }
        }
    }

    /// Units whose notation the step shows.
    static func notationUnits(_ step: SessionStep) -> [String] {
        switch step {
        case .echo(let b): b.showNotation ? b.items.map(\.unitID) : []
        case .read(let b): b.items.map(\.unitID)
        case .nameNotation(let q): [q.item.unitID]
        case .dictation(let d): [d.item.unitID]
        case .meterFromNotation(let m): [m.unitID]
        case .compose(let c): [c.unitID]
        case .readPhrase(let p): p.phrases.flatMap { $0.compactMap { Fixtures.curriculum.unit(containing: $0.id)?.id } }
        case .whichMeter, .sameOrDifferent, .answerDifferently: []
        }
    }
}
