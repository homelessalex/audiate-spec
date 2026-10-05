/// One cell of the curriculum grid: a unit at a skill level.
public struct LevelKey: Codable, Hashable, Sendable, CustomStringConvertible {
    public let unitID: String
    public let level: SkillLevel

    public init(unitID: String, level: SkillLevel) {
        self.unitID = unitID
        self.level = level
    }

    public var description: String { "\(unitID) \(level.code)" }
}
