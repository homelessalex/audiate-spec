public struct OnsetGrade: Hashable, Sendable {
    public struct Hit: Hashable, Sendable {
        public let expected: Double
        /// The tap as recorded (latency-compensated, not tempo-mapped).
        public let tap: Double
        /// Signed error after relative-mode mapping; negative = early.
        public let error: Double
    }

    public let hits: [Hit]
    public let misses: [Double]
    public let extras: [Double]
    public let meanAbsError: Double
    public let maxAbsError: Double
    /// Fitted tap-time scale in relative mode (> 1 = learner slowed down).
    public let tempoRatio: Double?
    public let tolerance: Double
    public let passed: Bool
    /// hits / (expected + extras), for rolling statistics.
    public let accuracy: Double
}
