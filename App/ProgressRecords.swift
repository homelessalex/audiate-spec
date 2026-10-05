import AudiateCore
import Foundation
import SwiftData

/// SwiftData mirrors of AudiateCore's plain progress types (docs/05-architecture.md §7).
@Model
final class AttemptRecord {
    var date: Date
    var unitID: String
    var level: String
    var patternID: String?
    var exercise: String
    var mode: String
    var passed: Bool
    var accuracy: Double

    init(_ a: Attempt) {
        date = a.date
        unitID = a.unitID
        level = a.level.rawValue
        patternID = a.patternID
        exercise = a.exercise.rawValue
        mode = a.mode.rawValue
        passed = a.passed
        accuracy = a.accuracy
    }

    var attempt: Attempt? {
        guard let level = SkillLevel(rawValue: level), let exercise = ExerciseKind(rawValue: exercise),
              let mode = PracticeMode(rawValue: mode) else { return nil }
        return Attempt(date: date, unitID: unitID, level: level, patternID: patternID, exercise: exercise,
                       mode: mode, passed: passed, accuracy: accuracy)
    }
}

@Model
final class ItemStateRecord {
    @Attribute(.unique) var id: String
    var subject: String
    var level: String
    var box: Int
    var dueDate: Date
    var consecutiveFails: Int

    init(_ s: ItemState) {
        id = s.key.description
        subject = s.key.subject
        level = s.key.level.rawValue
        box = s.box
        dueDate = s.dueDate
        consecutiveFails = s.consecutiveFails
    }

    func update(from s: ItemState) {
        box = s.box
        dueDate = s.dueDate
        consecutiveFails = s.consecutiveFails
    }

    var state: ItemState? {
        guard let level = SkillLevel(rawValue: level) else { return nil }
        return ItemState(key: ItemKey(subject: subject, level: level), box: box, dueDate: dueDate, consecutiveFails: consecutiveFails)
    }
}

@Model
final class LevelPassRecord {
    @Attribute(.unique) var id: String
    var unitID: String
    var level: String
    var passedAt: Date

    init(_ key: LevelKey, passedAt: Date) {
        id = key.description
        unitID = key.unitID
        level = key.level.rawValue
        self.passedAt = passedAt
    }

    var key: LevelKey? { SkillLevel(rawValue: level).map { LevelKey(unitID: unitID, level: $0) } }
}
