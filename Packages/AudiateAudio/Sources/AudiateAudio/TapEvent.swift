public struct TapEvent: Hashable, Sendable {
    public let key: TapKey
    public let isDown: Bool
    /// `NSEvent.timestamp`: seconds since boot, same clock as host time.
    public let timestamp: Double
}
