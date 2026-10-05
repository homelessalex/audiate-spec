import Foundation

/// One graded attempt, as plain data (SwiftData maps to/from this at the app boundary).
public struct Attempt: Codable, Hashable, Sendable {
    public let date: Date
    public let unitID: String
    public let level: SkillLevel
    /// nil for inference levels (generated patterns).
    public let patternID: String?
    public let exercise: ExerciseKind
    public let mode: PracticeMode
    public let passed: Bool
    /// 0…1; hits / (expected + extras) for tap exercises, 1 or 0 for choices.
    public let accuracy: Double

    public init(date: Date, unitID: String, level: SkillLevel, patternID: String?, exercise: ExerciseKind,
                mode: PracticeMode, passed: Bool, accuracy: Double) {
        self.date = date
        self.unitID = unitID
        self.level = level
        self.patternID = patternID
        self.exercise = exercise
        self.mode = mode
        self.passed = passed
        self.accuracy = accuracy
    }

    public var levelKey: LevelKey { LevelKey(unitID: unitID, level: level) }

    /// The Leitner item this attempt reviews.
    public var itemKey: ItemKey { ItemKey(subject: patternID ?? unitID, level: level) }
}
