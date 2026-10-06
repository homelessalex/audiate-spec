import Foundation
@testable import AudiateCore

/// What a learner who gets everything right records for one step (used by planner simulations).
enum StepAttempts {
    static func perfect(_ step: SessionStep, at date: Date) -> [Attempt] {
        func attempt(_ unitID: String, _ level: SkillLevel, _ patternID: String?, _ exercise: ExerciseKind, _ mode: PracticeMode) -> Attempt {
            Attempt(date: date, unitID: unitID, level: level, patternID: patternID, exercise: exercise, mode: mode, passed: true, accuracy: 1)
        }
        switch step {
        case .echo(let b): return b.items.map { attempt($0.unitID, $0.level, $0.patternID, b.exercise, b.mode) }
        case .read(let b): return b.items.map { attempt($0.unitID, $0.level, $0.patternID, .read, b.mode) }
        case .nameNotation(let q): return [attempt(q.item.unitID, q.item.level, q.item.patternID, .nameNotation, q.mode)]
        case .dictation(let d): return [attempt(d.item.unitID, d.item.level, d.item.patternID, .write, d.mode)]
        case .holdPulse(let h): return [attempt(h.unitID, .aural, nil, .holdThePulse, .practice)]
        case .whichMeter(let w): return [attempt(w.unitID, w.level, nil, .whichMeter, .evaluation)]
        case .meterFromNotation(let m): return [attempt(m.unitID, .compositeSynthesis, nil, .meterFromNotation, .evaluation)]
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
        case .holdPulse, .whichMeter: []
        }
    }
}
