public enum LevelStatus: String, Codable, Hashable, Sendable {
    case locked
    case available
    case inProgress
    case passed
}
