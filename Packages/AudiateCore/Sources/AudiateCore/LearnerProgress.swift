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

    /// Taught at `level`: performed correctly in teaching mode, or the teaching attempts ran out.
    public func isIntroduced(patternID: String, level: SkillLevel) -> Bool {
        let teaching = attempts.filter { $0.patternID == patternID && $0.level == level && $0.mode == .teaching }
        return teaching.contains(where: \.passed) || teaching.count >= MasteryPolicy.maxTeachingAttempts
    }

    /// Evaluation attempts at `level` with `exercise` on the calendar day of `date`.
    public func evaluationsOnDay(of date: Date, patternID: String, level: SkillLevel, exercise: ExerciseKind,
                                 calendar: Calendar) -> Int {
        attempts.filter {
            $0.mode == .evaluation && $0.patternID == patternID && $0.level == level && $0.exercise == exercise
                && calendar.isDate($0.date, inSameDayAs: date)
        }.count
    }

    /// Unit-level evaluations (no pattern: E3, E7) or any-pattern evaluations of the unit at `level`
    /// with `exercise` on the calendar day of `date`.
    public func unitEvaluationsOnDay(of date: Date, unitID: String, level: SkillLevel, exercise: ExerciseKind,
                                     calendar: Calendar) -> Int {
        attempts.filter {
            $0.mode != .teaching && $0.unitID == unitID && $0.level == level && $0.exercise == exercise
                && calendar.isDate($0.date, inSameDayAs: date)
        }.count
    }

    /// Whether the pattern's teaching at `level` started on the calendar day of `date`.
    public func teachingStarted(onDayOf date: Date, patternID: String, level: SkillLevel, calendar: Calendar) -> Bool {
        let first = attempts.first { $0.patternID == patternID && $0.level == level && $0.mode == .teaching }
        return first.map { calendar.isDate($0.date, inSameDayAs: date) } ?? false
    }

    /// The pattern has been taught by ear.
    public func hasHeard(patternID: String) -> Bool {
        isIntroduced(patternID: patternID, level: .aural)
    }

    public func dueItems(on date: Date) -> [ItemState] {
        LeitnerScheduler.due(Array(items.values), on: date)
    }

    /// Records an attempt: updates review boxes (evaluation only), schedules bridges and checks mastery.
    /// Returns the levels that became passed.
    @discardableResult
    public mutating func record(_ attempt: Attempt, curriculum: Curriculum, library: PatternLibrary, calendar: Calendar) -> [LevelKey] {
        attempts.append(attempt)
        // phrases (E13) move their own ladder, derived from the attempts: no review item, no level
        guard attempt.mode == .evaluation, attempt.exercise != .readPhrase else { return [] }

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
