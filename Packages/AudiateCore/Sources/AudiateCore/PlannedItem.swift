/// One pattern scheduled in a session.
public struct PlannedItem: Hashable, Sendable {
    public enum Purpose: String, Hashable, Sendable {
        case new
        case review
        case bridge
    }

    public let patternID: String
    public let unitID: String
    public let level: SkillLevel
    public let purpose: Purpose

    public init(patternID: String, unitID: String, level: SkillLevel, purpose: Purpose) {
        self.patternID = patternID
        self.unitID = unitID
        self.level = level
        self.purpose = purpose
    }
}
