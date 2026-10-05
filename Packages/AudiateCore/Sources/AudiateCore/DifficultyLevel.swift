public enum DifficultyLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case easy
    case moderate
    case difficult

    public static func < (lhs: DifficultyLevel, rhs: DifficultyLevel) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
