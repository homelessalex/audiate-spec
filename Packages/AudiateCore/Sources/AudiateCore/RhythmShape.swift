/// What a pattern sounds like, independent of its id and meter name.
/// Two patterns with equal shapes are the same pattern to the ear (used for "unfamiliar" checks).
public struct RhythmShape: Hashable, Sendable {
    public let macrobeats: [Int]
    public let events: [RhythmEvent]
}
