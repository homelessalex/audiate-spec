/// Where one prompt pattern sounds, in seconds from block start.
public struct PromptSlot: Hashable, Sendable {
    public let patternID: String
    /// Prompt measure start minus the pickup.
    public let start: Double
    public let end: Double
    public let cues: [SyllableCue]
}
