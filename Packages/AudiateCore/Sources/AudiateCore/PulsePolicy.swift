/// E10 "hold the pulse" (docs/04-exercises.md §6).
public enum PulsePolicy {
    /// Silent stretch lengths, growing with successive passes and shrinking after a miss.
    public static let silentMeasures = [2, 4, 8, 16]
    /// Measures with the click after the count-in, before the silence (time to lock into the beat).
    public static let clickedMeasures = 2
    /// |last tap − last beat| as a fraction of a macrobeat.
    public static let maxDrift = 0.10
    /// Standard deviation of the tap intervals relative to the beat intervals.
    public static let maxJitter = 0.06

    /// Next silent length from the E10 history (oldest first): pass → one step up, miss → one step down.
    public static func silentMeasures(after history: [Bool]) -> Int {
        var step = 0
        for passed in history {
            step = passed ? min(step + 1, silentMeasures.count - 1) : max(step - 1, 0)
        }
        return silentMeasures[step]
    }
}
