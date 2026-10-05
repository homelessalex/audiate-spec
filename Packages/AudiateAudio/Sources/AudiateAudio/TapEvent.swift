public struct TapEvent: Hashable, Sendable {
    public let key: TapKey
    public let isDown: Bool
    /// `NSEvent.timestamp`: seconds since boot, same clock as host time.
    public let timestamp: Double

    public init(key: TapKey, isDown: Bool, timestamp: Double) {
        self.key = key
        self.isDown = isDown
        self.timestamp = timestamp
    }
}
