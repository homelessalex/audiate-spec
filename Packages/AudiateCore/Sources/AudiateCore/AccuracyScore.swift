/// One number for "how close was it": the mean |error| over the notes hit, on a scale ending at the
/// tolerance (a note at the very edge). A missed note or an extra tap puts it at the end. Not a picture
/// of the rhythm, so it can be shown before SA.
public struct AccuracyScore: Hashable, Sendable {
    /// Mean |tap − note|, seconds.
    public let meanError: Double
    /// The scale's end, seconds.
    public let maximum: Double
    /// Where the mean must stay to pass, as a fraction of the scale (nil when no such rule applies).
    public let passLimit: Double?
    /// A miss, an extra tap or a lost count.
    public let isMax: Bool

    public init(meanError: Double, maximum: Double, passLimit: Double?, isMax: Bool) {
        self.meanError = meanError
        self.maximum = maximum
        self.passLimit = passLimit
        self.isMax = isMax
    }

    public init(_ grade: OnsetGrade) {
        self.init(meanError: grade.meanAbsError, maximum: grade.tolerance,
                  passLimit: OnsetGraderPolicy.maxMeanErrorFraction,
                  isMax: !grade.misses.isEmpty || !grade.extras.isEmpty || grade.hits.isEmpty)
    }

    public init(_ grade: PulseGrade) {
        self.init(meanError: grade.totalError / Double(max(min(grade.taps, grade.beats), 1)),
                  maximum: OnsetGraderPolicy.maxTolerance, passLimit: nil, isMax: grade.problems.contains(.lostCount))
    }

    /// Both hands together: the mean over all notes hit; the scale ends at their mean tolerance.
    public init(_ grade: TwoHandGrade) {
        let a = grade.rhythm, b = grade.pulse
        let hits = Double(max(a.hits.count + b.hits.count, 1))
        let errors = a.hits.map { abs($0.error) } + b.hits.map { abs($0.error) }
        self.init(meanError: errors.reduce(0, +) / hits,
                  maximum: (a.tolerance * Double(a.hits.count) + b.tolerance * Double(b.hits.count)) / hits,
                  passLimit: OnsetGraderPolicy.maxMeanErrorFraction,
                  isMax: AccuracyScore(a).isMax || AccuracyScore(b).isMax)
    }

    /// 0 (every note dead on) … 1 (at the tolerance, or a miss/extra).
    public var fraction: Double { isMax ? 1 : min(1, meanError / max(maximum, 1e-9)) }
}
