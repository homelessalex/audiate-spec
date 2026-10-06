/// E2: hear a pattern twice, then pick its notation from the options (no time limit; the pulse stops
/// while the learner chooses). Replaces Gordon's syllable naming at VA (docs/01-methodology.md §7).
public struct NameNotationSpec: Hashable, Sendable {
    public let item: PlannedItem
    public let tempo: Tempo
    /// One of them is the pattern itself; the others sound different.
    public let options: [Pattern]
    public let correctIndex: Int
    public let mode: PracticeMode

    public init(item: PlannedItem, tempo: Tempo, options: [Pattern], correctIndex: Int, mode: PracticeMode) {
        self.item = item
        self.tempo = tempo
        self.options = options
        self.correctIndex = correctIndex
        self.mode = mode
    }
}
