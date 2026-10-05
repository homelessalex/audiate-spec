/// `tapBlockTime = eventTime − outputLatency − inputOffset` (docs/05-architecture.md §4).
public struct LatencyCompensation: Hashable, Sendable {
    /// Audio reaches the ear this much later than its scheduled time.
    public var outputLatency: Double
    /// The learner's calibrated median tap offset.
    public var inputOffset: Double

    public init(outputLatency: Double, inputOffset: Double) {
        self.outputLatency = outputLatency
        self.inputOffset = inputOffset
    }

    public func blockTime(forRawBlockTime raw: Double) -> Double {
        raw - outputLatency - inputOffset
    }
}
