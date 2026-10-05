/// E1: an uninterrupted block of echoes in one meter.
public struct EchoBlockSpec: Hashable, Sendable {
    public let items: [PlannedItem]
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode
    /// Syllables shown in sync with the prompt (VA teaching mode).
    public let showSyllables: Bool
}
