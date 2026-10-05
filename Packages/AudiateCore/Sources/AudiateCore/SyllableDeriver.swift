/// Derives a syllable from a position in the meter (docs/03-rhythm-model.md §2).
public struct SyllableDeriver: Sendable {
    public var table: SyllableTable

    public init(table: SyllableTable = .standard) {
        self.table = table
    }

    public func syllable(in meter: Meter, atTick tick: Int) throws -> String {
        let span = meter.macrobeat(containing: tick)
        let offset = tick.floorMod(meter.measureTicks) - span.startTick
        let tpm = Rhythm.ticksPerMicrobeat
        if offset % tpm == 0 {
            return try table.microbeats(macrobeatSize: span.microbeats, unusual: meter.isUnusual)[offset / tpm]
        }
        if offset % tpm == Rhythm.divisionTicks {
            return table.division
        }
        if meter.allowsThirds, span.microbeats == 2, offset % Rhythm.thirdTicks == 0 {
            return table.thirds[offset / Rhythm.thirdTicks]
        }
        throw RhythmError.notOnSyllableGrid(meterID: meter.id, tick: tick)
    }

    /// note → `Du`, rest → `(Du)`, continuation → `[Du]`.
    public func display(for event: RhythmEvent, in meter: Meter) throws -> String {
        let s = try syllable(in: meter, atTick: event.startTick)
        switch event.kind {
        case .note: return s
        case .rest: return "(\(s))"
        case .continuation: return "[\(s)]"
        }
    }

    public func displays(for pattern: Pattern) throws -> [String] {
        try pattern.events.map { try display(for: $0, in: pattern.meter) }
    }

    /// Space-separated display forms, e.g. `de Du (de) Du`.
    public func line(for pattern: Pattern) throws -> String {
        try displays(for: pattern).joined(separator: " ")
    }
}
