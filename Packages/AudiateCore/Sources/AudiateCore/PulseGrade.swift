public struct PulseGrade: Hashable, Sendable {
    public enum Problem: String, Hashable, Sendable {
        /// Fewer or more taps than beats in the silence.
        case lostCount
        /// Ended too far from the beat (`drift` says which way).
        case drifted
        /// Beats were uneven.
        case uneven
    }

    /// (last tap − last beat) / mean beat; positive = late (slowed down).
    public let drift: Double
    /// Standard deviation of tap intervals relative to beat intervals.
    public let jitter: Double
    public let taps: Int
    public let beats: Int
    public let problems: [Problem]

    public var passed: Bool { problems.isEmpty }
}
