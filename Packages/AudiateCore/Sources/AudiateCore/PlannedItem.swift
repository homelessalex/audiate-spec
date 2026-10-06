/// One pattern scheduled in a session.
public struct PlannedItem: Hashable, Sendable {
    public enum Purpose: String, Hashable, Sendable {
        case new
        case review
        case bridge
        /// An unfamiliar pattern from the generator (inference levels).
        case generated
    }

    public let patternID: String
    public let unitID: String
    public let level: SkillLevel
    public let purpose: Purpose
    /// The pattern itself when it is not in the library (generated); nil for library patterns.
    public let generated: Pattern?

    public init(patternID: String, unitID: String, level: SkillLevel, purpose: Purpose) {
        self.patternID = patternID
        self.unitID = unitID
        self.level = level
        self.purpose = purpose
        generated = nil
    }

    /// An item for a generated (unfamiliar) pattern.
    public init(generated pattern: Pattern, unitID: String, level: SkillLevel) {
        patternID = pattern.id
        self.unitID = unitID
        self.level = level
        purpose = .generated
        generated = pattern
    }

    public func pattern(in library: PatternLibrary) -> Pattern? { generated ?? library.pattern(id: patternID) }
}
