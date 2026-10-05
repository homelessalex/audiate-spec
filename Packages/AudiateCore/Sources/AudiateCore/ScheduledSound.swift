public struct ScheduledSound: Hashable, Sendable {
    /// Seconds from block start.
    public let time: Double
    public let sound: Sound

    public init(time: Double, sound: Sound) {
        self.time = time
        self.sound = sound
    }
}
