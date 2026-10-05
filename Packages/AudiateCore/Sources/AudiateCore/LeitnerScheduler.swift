import Foundation

/// Spaced review in Leitner boxes (docs/02-curriculum.md §4): pass → up one box, fail → box 1.
public enum LeitnerScheduler {
    public static func update(_ state: ItemState?, key: ItemKey, passed: Bool, date: Date, calendar: Calendar) -> ItemState {
        let maxBox = MasteryPolicy.reviewIntervalsDays.count
        let box = passed ? min((state?.box ?? 0) + 1, maxBox) : 1
        let days = MasteryPolicy.reviewIntervalsDays[box - 1]
        let due = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date))!
        return ItemState(key: key, box: box, dueDate: due, consecutiveFails: passed ? 0 : (state?.consecutiveFails ?? 0) + 1)
    }

    /// Items due on `date`, oldest due first.
    public static func due(_ states: [ItemState], on date: Date) -> [ItemState] {
        states.filter { $0.dueDate <= date }.sorted { ($0.dueDate, $0.key.description) < ($1.dueDate, $1.key.description) }
    }

    /// Two consecutive fails at a symbolic/inference level → the same subject at the previous aural level.
    public static func bridge(for state: ItemState) -> ItemKey? {
        guard state.consecutiveFails >= MasteryPolicy.failsBeforeBridge, let level = state.key.level.bridgeLevel else { return nil }
        return ItemKey(subject: state.key.subject, level: level)
    }
}
