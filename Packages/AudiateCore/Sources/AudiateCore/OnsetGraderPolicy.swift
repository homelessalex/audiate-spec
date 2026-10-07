/// Constants of the onset grader (docs/04-exercises.md §2).
public enum OnsetGraderPolicy {
    static let maxPreWindow = 0.12
    static let preWindowFraction = 0.5
    static let toleranceFraction = 0.25
    static let minTolerance = 0.035
    static let maxTolerance = 0.080
    static let maxMeanErrorFraction = 0.5
    static let relativeSlopeRange = 0.85...1.15
    /// Relative-mode fit priors (docs/04-exercises.md §2 step 3). The fit forgives a phase offset and a
    /// tempo change only as far as the taps give evidence for them; with few notes it barely moves, so
    /// it cannot absorb the timing errors it is meant to measure. [uncertain] tune on real attempts.
    /// Typical spread of one tap, seconds.
    static let relativeTapSpread = 0.025
    /// Typical tempo change without the click, as a fraction (0.05 = 5 % slower or faster).
    static let relativeTempoSpread = 0.05
    /// Typical phase offset of the whole response, seconds.
    static let relativeOffset = 0.020
    static let maxTempoDrift = 0.08
    public static let debounce = 0.030
}
