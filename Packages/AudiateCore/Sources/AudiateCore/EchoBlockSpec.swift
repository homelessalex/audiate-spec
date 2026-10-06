/// E1: an uninterrupted block of echoes in one meter.
public struct EchoBlockSpec: Hashable, Sendable {
    public let items: [PlannedItem]
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode
    /// The pattern's notation is shown during the echo (VA: notation association).
    public let showNotation: Bool
}
