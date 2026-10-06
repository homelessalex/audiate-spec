/// E9: write your own pattern with the cell palette, then perform it from the notation (IS).
public struct ComposeSpec: Hashable, Sendable {
    public let unitID: String
    public let meterID: String
    public let palette: [Cell]
    public let tempo: Tempo

    public init(unitID: String, meterID: String, palette: [Cell], tempo: Tempo) {
        self.unitID = unitID
        self.meterID = meterID
        self.palette = palette
        self.tempo = tempo
    }
}
