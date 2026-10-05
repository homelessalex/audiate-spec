/// One measure plus an optional pickup. Syllables and notation are derived, never stored.
public struct Pattern: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let meter: Meter
    public let content: ContentKind
    public let pickupTicks: Int
    public let events: [RhythmEvent]

    public init(id: String, meter: Meter, content: ContentKind, pickupTicks: Int, events: [RhythmEvent]) {
        self.id = id
        self.meter = meter
        self.content = content
        self.pickupTicks = pickupTicks
        self.events = events
    }

    public var measureTicks: Int { meter.measureTicks }

    public func isPickup(_ event: RhythmEvent) -> Bool { event.startTick < 0 }

    public var onsets: [RhythmEvent] { events.filter(\.isOnset) }

    public var shape: RhythmShape { RhythmShape(macrobeats: meter.macrobeats, events: events) }
}
