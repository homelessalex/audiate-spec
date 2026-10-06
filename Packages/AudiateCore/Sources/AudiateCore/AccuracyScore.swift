/// One number for "how close was it": the sum of |error| over all hits, on a scale whose maximum is
/// every note at the edge of its tolerance. A missed note or an extra tap puts it at the maximum.
/// Not a picture of the rhythm, so it can be shown before SA.
public struct AccuracyScore: Hashable, Sendable {
    /// Σ|tap − note|, seconds.
    public let totalError: Double
    /// The scale's end, seconds.
    public let maximum: Double
    /// A miss, an extra tap or a lost count.
    public let isMax: Bool

    public init(totalError: Double, maximum: Double, isMax: Bool) {
        self.totalError = totalError
        self.maximum = maximum
        self.isMax = isMax
    }

    public init(_ grade: OnsetGrade) {
        let notes = grade.hits.count + grade.misses.count
        self.init(totalError: grade.hits.map { abs($0.error) }.reduce(0, +),
                  maximum: grade.tolerance * Double(max(notes, 1)),
                  isMax: !grade.misses.isEmpty || !grade.extras.isEmpty)
    }

    public init(_ grade: PulseGrade) {
        self.init(totalError: grade.totalError, maximum: OnsetGraderPolicy.maxTolerance * Double(max(grade.beats, 1)),
                  isMax: grade.problems.contains(.lostCount))
    }

    /// Both hands together.
    public init(_ grade: TwoHandGrade) {
        let a = AccuracyScore(grade.rhythm), b = AccuracyScore(grade.pulse)
        self.init(totalError: a.totalError + b.totalError, maximum: a.maximum + b.maximum, isMax: a.isMax || b.isMax)
    }

    /// 0 (perfect) … 1 (at or past the maximum).
    public var fraction: Double { isMax ? 1 : min(1, totalError / max(maximum, 1e-9)) }
}
