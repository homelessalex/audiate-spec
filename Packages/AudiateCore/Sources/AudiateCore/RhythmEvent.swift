public struct RhythmEvent: Codable, Hashable, Sendable {
    /// Ticks from the barline; negative for pickup events.
    public let startTick: Int
    public let ticks: Int
    public let kind: EventKind
    public let tieToNext: Bool

    public init(startTick: Int, ticks: Int, kind: EventKind, tieToNext: Bool) {
        self.startTick = startTick
        self.ticks = ticks
        self.kind = kind
        self.tieToNext = tieToNext
    }

    public var endTick: Int { startTick + ticks }
    public var isOnset: Bool { kind == .note }
}
