public enum PracticeMode: String, Codable, Hashable, Sendable {
    /// Presented with support (syllables visible, click stage A); does not count toward mastery.
    case teaching
    /// Performed alone, once; graded for mastery.
    case evaluation
}
