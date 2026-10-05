public struct CalibrationResult: Hashable, Sendable {
    /// tap − click for each kept click that got a tap.
    public let offsets: [Double]
    public let medianOffset: Double?
    public let iqr: Double?
    public let isAccepted: Bool
}
