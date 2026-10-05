/// A review item: a pattern at a familiar-pattern level, or a unit at an inference level.
public struct ItemKey: Codable, Hashable, Sendable, CustomStringConvertible {
    /// Pattern id, or unit id for inference levels.
    public let subject: String
    public let level: SkillLevel

    public init(subject: String, level: SkillLevel) {
        self.subject = subject
        self.level = level
    }

    public var description: String { "\(subject) \(level.code)" }
}
