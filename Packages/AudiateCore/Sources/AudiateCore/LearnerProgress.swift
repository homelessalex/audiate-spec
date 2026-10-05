import Foundation

/// Everything the scheduler needs to know about the learner, as plain data.
public struct LearnerProgress: Codable, Hashable, Sendable {
    public private(set) var attempts: [Attempt]
    public private(set) var items: [ItemKey: ItemState]
    /// Passed levels and when they passed. Never removed.
    public private(set) var passedAt: [LevelKey: Date]

    public init(attempts: [Attempt] = [], items: [ItemKey: ItemState] = [:], passedAt: [LevelKey: Date] = [:]) {
        self.attempts = attempts
        self.items = items
        self.passedAt = passedAt
    }

    public var passed: Set<LevelKey> { Set(passedAt.keys) }
    public var started: Set<LevelKey> { Set(attempts.map(\.levelKey)) }

    public func status(of key: LevelKey, curriculum: Curriculum) -> LevelStatus {
        Gate.status(of: key, curriculum: curriculum, passed: passed, started: started)
    }

    public func teachingCount(patternID: String, level: SkillLevel) -> Int {
        attempts.filter { $0.patternID == patternID && $0.level == level && $0.mode == .teaching }.count
    }

    public func dueItems(on date: Date) -> [ItemState] {
        LeitnerScheduler.due(Array(items.values), on: date)
    }

    /// Records an attempt: updates review boxes (evaluation only), schedules bridges and checks mastery.
    /// Returns the levels that became passed.
    @discardableResult
    public mutating func record(_ attempt: Attempt, curriculum: Curriculum, library: PatternLibrary, calendar: Calendar) -> [LevelKey] {
        attempts.append(attempt)
        guard attempt.mode == .evaluation else { return [] }

        let key = attempt.itemKey
        let state = LeitnerScheduler.update(items[key], key: key, passed: attempt.passed, date: attempt.date, calendar: calendar)
        items[key] = state
        if let bridge = LeitnerScheduler.bridge(for: state) {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: attempt.date))!
            let existing = items[bridge]
            items[bridge] = ItemState(key: bridge, box: existing?.box ?? 1, dueDate: min(existing?.dueDate ?? tomorrow, tomorrow),
                                      consecutiveFails: existing?.consecutiveFails ?? 0)
        }

        let level = attempt.levelKey
        guard passedAt[level] == nil, let unit = curriculum.unit(id: attempt.unitID) else { return [] }
        let patternIDs = curriculum.patterns(of: unit, in: library).map(\.id)
        guard MasteryEvaluator.isPassed(level, patternIDs: patternIDs, attempts: attempts, calendar: calendar) else { return [] }
        passedAt[level] = attempt.date
        return [level]
    }
}
