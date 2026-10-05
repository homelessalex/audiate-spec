/// Where the learner answers one prompt, in seconds from block start.
public struct ResponseSlot: Hashable, Sendable {
    public let patternID: String
    /// Response measure start minus the pickup.
    public let start: Double
    public let end: Double
    /// Onsets of `note` events only.
    public let expectedOnsets: [Double]
    /// Macrobeat starts of the response measure (two-hand mode).
    public let macrobeatTimes: [Double]
}
