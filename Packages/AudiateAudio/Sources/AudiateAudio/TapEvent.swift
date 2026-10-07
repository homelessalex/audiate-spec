public struct TapEvent: Hashable, Sendable {
    public let key: TapKey
    public let isDown: Bool
    /// Seconds on the host-time clock (`NSEvent.timestamp`, or a MIDI packet's host time).
    public let timestamp: Double
    public let source: InputSource

    public init(key: TapKey, isDown: Bool, timestamp: Double, source: InputSource = .computer) {
        self.key = key
        self.isDown = isDown
        self.timestamp = timestamp
        self.source = source
    }
}
