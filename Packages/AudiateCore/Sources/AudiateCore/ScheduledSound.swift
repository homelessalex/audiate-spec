public struct ScheduledSound: Hashable, Sendable {
    /// Seconds from block start.
    public let time: Double
    public let sound: Sound
    /// How long the sound sustains before it is choked; nil = let the one-shot ring out.
    public let duration: Double?

    public init(time: Double, sound: Sound, duration: Double? = nil) {
        self.time = time
        self.sound = sound
        self.duration = duration
    }
}
