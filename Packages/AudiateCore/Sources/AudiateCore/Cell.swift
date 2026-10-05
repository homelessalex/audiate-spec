/// A macrobeat-sized building block for unfamiliar patterns (data/cells.json).
public struct Cell: Hashable, Sendable {
    public let macrobeatSize: Int
    public let tokens: [RhythmToken]
    /// Lowest content level that unlocks this cell.
    public let minContent: ContentKind

    public init(macrobeatSize: Int, tokens: [RhythmToken], minContent: ContentKind) {
        self.macrobeatSize = macrobeatSize
        self.tokens = tokens
        self.minContent = minContent
    }

    public var ticks: Int { tokens.map(\.ticks).reduce(0, +) }
}
