/// What the learner is told after an echo before notation is allowed: counts only, no visual rhythm.
public struct EchoFeedback: Hashable, Sendable {
    public let onTime: Int
    public let early: Int
    public let late: Int
    public let missed: Int
    public let extra: Int

    /// A hit counts as early/late beyond this fraction of the tolerance.
    public static let earlyLateFraction = 0.5

    public init(_ grade: OnsetGrade) {
        let limit = Self.earlyLateFraction * grade.tolerance
        onTime = grade.hits.filter { abs($0.error) <= limit }.count
        early = grade.hits.filter { $0.error < -limit }.count
        late = grade.hits.filter { $0.error > limit }.count
        missed = grade.misses.count
        extra = grade.extras.count
    }
}
