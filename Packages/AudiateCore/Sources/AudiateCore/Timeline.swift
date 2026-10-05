/// A block turned into time: every sound to schedule and every response to grade (docs/04-exercises.md §1).
public struct Timeline: Hashable, Sendable {
    /// Sorted by time.
    public let sounds: [ScheduledSound]
    /// One entry per measure.
    public let measureRoles: [MeasureRole]
    public let prompts: [PromptSlot]
    public let responses: [ResponseSlot]
    public let measureDuration: Double
    /// End of the last measure (sample tails may ring past it).
    public let duration: Double

    /// The role of the measure sounding at `time` (nil before the start or after the end).
    public func role(at time: Double) -> MeasureRole? {
        guard time >= 0, measureDuration > 0 else { return nil }
        let m = Int(time / measureDuration)
        return measureRoles.indices.contains(m) ? measureRoles[m] : nil
    }

    public init(sounds: [ScheduledSound], measureRoles: [MeasureRole] = [], prompts: [PromptSlot] = [],
                responses: [ResponseSlot] = [], measureDuration: Double, duration: Double) {
        self.sounds = sounds
        self.measureRoles = measureRoles
        self.prompts = prompts
        self.responses = responses
        self.measureDuration = measureDuration
        self.duration = duration
    }
}
