import Foundation

/// When a level counts as passed for a unit (docs/02-curriculum.md §4).
public enum MasteryEvaluator {
    /// Familiar-pattern levels: every pattern has enough evaluation passes on enough days,
    /// and the rolling accuracy of recent evaluation attempts is high enough.
    public static func isPassed(_ key: LevelKey, patternIDs: [String], attempts: [Attempt], calendar: Calendar) -> Bool {
        let evaluations = attempts.filter { $0.levelKey == key && $0.mode == .evaluation }.sorted { $0.date < $1.date }
        if key.level.isUnitLevel {
            let days = Set(evaluations.map { calendar.startOfDay(for: $0.date) })
            let needed = key.level.isInference ? MasteryPolicy.inferenceAttempts : MasteryPolicy.unitLevelAttempts
            let accuracy = key.level.isInference ? MasteryPolicy.inferenceRollingAccuracy : MasteryPolicy.unitLevelRollingAccuracy
            return evaluations.count >= needed
                && days.count >= MasteryPolicy.inferenceDistinctDays
                && rollingAccuracy(evaluations, window: needed) >= accuracy
        }
        guard !patternIDs.isEmpty else { return false }
        for id in patternIDs {
            let passes = evaluations.filter { $0.patternID == id && $0.passed }
            let days = Set(passes.map { calendar.startOfDay(for: $0.date) })
            if passes.count < MasteryPolicy.passesPerPattern || days.count < MasteryPolicy.distinctDaysPerPattern {
                return false
            }
        }
        return rollingAccuracy(evaluations, window: MasteryPolicy.rollingWindow) >= MasteryPolicy.rollingAccuracy
    }

    /// Mean accuracy of the last `window` attempts (fewer if there aren't that many).
    public static func rollingAccuracy(_ sortedAttempts: [Attempt], window: Int) -> Double {
        let recent = sortedAttempts.suffix(window)
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.accuracy).reduce(0, +) / Double(recent.count)
    }
}
