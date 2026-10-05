/// A block turned into time: every sound to schedule and every response to grade (docs/04-exercises.md §1).
public struct Timeline: Hashable, Sendable {
    /// Sorted by time.
    public let sounds: [ScheduledSound]
    public let prompts: [PromptSlot]
    public let responses: [ResponseSlot]
    public let measureDuration: Double
    /// End of the last measure (sample tails may ring past it).
    public let duration: Double

    public init(sounds: [ScheduledSound], prompts: [PromptSlot] = [], responses: [ResponseSlot] = [],
                measureDuration: Double, duration: Double) {
        self.sounds = sounds
        self.prompts = prompts
        self.responses = responses
        self.measureDuration = measureDuration
        self.duration = duration
    }
}
