/// E6: hear a pattern twice, then write it with one cell per macrobeat (no time limit).
public struct DictationSpec: Hashable, Sendable {
    public let item: PlannedItem
    public let tempo: Tempo
    /// The pattern split into cells, one per macrobeat.
    public let answer: [Cell]
    /// Cells offered per macrobeat size (always includes the answer's).
    public let palette: [Cell]
    public let mode: PracticeMode
}
