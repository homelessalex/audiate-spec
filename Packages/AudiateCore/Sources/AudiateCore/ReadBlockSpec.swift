/// E5: read patterns from notation. Teaching: the pattern plays while its notation is shown, then the
/// learner reads it back. Evaluation: notation only.
public struct ReadBlockSpec: Hashable, Sendable {
    public let items: [PlannedItem]
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode

    /// The model is heard together with the notation (teaching).
    public var playsModel: Bool { mode == .teaching }
}
