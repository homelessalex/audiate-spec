/// One macrobeat of a measure, in ticks from the barline.
public struct MacrobeatSpan: Hashable, Sendable {
    public let index: Int
    public let startTick: Int
    public let microbeats: Int

    public var ticks: Int { microbeats * Rhythm.ticksPerMicrobeat }
    public var endTick: Int { startTick + ticks }
}
