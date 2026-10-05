/// E2: hear a pattern, pick its syllables from the options.
public struct NameSyllablesSpec: Hashable, Sendable {
    public let item: PlannedItem
    public let tempo: Tempo
    /// Syllable lines; one of them is the pattern's.
    public let options: [String]
    public let correctIndex: Int
    public let mode: PracticeMode

    /// Replays allowed after the first hearing.
    public var replays: Int { mode == .teaching ? 2 : 1 }
}
