/// Pulse grader limits, used by the pulse trainer (docs/04-exercises.md §6).
public enum PulsePolicy {
    /// |last tap − last beat| as a fraction of a macrobeat.
    public static let maxDrift = 0.10
    /// Standard deviation of the tap intervals relative to the beat intervals.
    public static let maxJitter = 0.06

}
