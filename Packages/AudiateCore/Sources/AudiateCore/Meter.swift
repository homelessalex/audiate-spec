/// A meter as an ordered list of macrobeat sizes in microbeats (docs/03-rhythm-model.md §1).
public struct Meter: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let macrobeats: [Int]
    /// True only for usual combined: a 2-microbeat macrobeat may be divided into thirds.
    public let allowsThirds: Bool
    public let timeSignature: TimeSignature

    public init(id: String, macrobeats: [Int], allowsThirds: Bool, timeSignature: TimeSignature) {
        self.id = id
        self.macrobeats = macrobeats
        self.allowsThirds = allowsThirds
        self.timeSignature = timeSignature
    }

    /// Unusual meters have unequal macrobeats (5/8, 7/8). Intact unusual meters are out of scope.
    public var isUnusual: Bool { Set(macrobeats).count > 1 }

    public var measureTicks: Int { macrobeats.reduce(0, +) * Rhythm.ticksPerMicrobeat }

    public var macrobeatSpans: [MacrobeatSpan] {
        var start = 0
        return macrobeats.enumerated().map { index, size in
            defer { start += size * Rhythm.ticksPerMicrobeat }
            return MacrobeatSpan(index: index, startTick: start, microbeats: size)
        }
    }

    /// The macrobeat containing `tick`; ticks outside the measure (pickups) wrap around.
    public func macrobeat(containing tick: Int) -> MacrobeatSpan {
        let t = tick.floorMod(measureTicks)
        return macrobeatSpans.last { $0.startTick <= t }!
    }
}
