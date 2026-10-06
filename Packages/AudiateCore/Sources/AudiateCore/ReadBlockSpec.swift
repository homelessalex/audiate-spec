/// E5: read patterns from notation. Teaching: the pattern plays while its notation is shown, then the
/// learner reads it back. Evaluation: notation only.
public struct ReadBlockSpec: Hashable, Sendable {
    public let items: [PlannedItem]
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode

    public init(items: [PlannedItem], meterID: String, tempo: Tempo, clickStage: ClickStage, mode: PracticeMode) {
        self.items = items
        self.meterID = meterID
        self.tempo = tempo
        self.clickStage = clickStage
        self.mode = mode
    }

    /// The model is heard together with the notation (teaching).
    public var playsModel: Bool { mode == .teaching }
}
