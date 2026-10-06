/// E10: a count-in and a measure with the click, then silence; tap the macrobeats through it.
public struct HoldPulseSpec: Hashable, Sendable {
    /// The unit whose meter is used (attempts are recorded against it as practice).
    public let unitID: String
    public let meterID: String
    public let tempo: Tempo
    public let silentMeasures: Int
}
