/// Rhythm content, in teaching order (docs/01-methodology.md §2, docs/02-curriculum.md §1).
public enum ContentKind: String, Codable, CaseIterable, Comparable, Sendable {
    case macroMicro = "macro_micro"
    case division
    case elongation
    case rest
    case tie
    case upbeat
    /// Triplets in duple (usual combined meter).
    case combined

    public static func < (lhs: ContentKind, rhs: ContentKind) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}
