/// Constants of the onset grader (docs/04-exercises.md §2).
public enum OnsetGraderPolicy {
    static let maxPreWindow = 0.12
    static let preWindowFraction = 0.5
    static let toleranceFraction = 0.25
    static let minTolerance = 0.035
    static let maxTolerance = 0.080
    static let maxMeanErrorFraction = 0.5
    static let relativeSlopeRange = 0.85...1.15
    static let maxTempoDrift = 0.08
    public static let debounce = 0.030
}
