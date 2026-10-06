/// Writing a pattern with macrobeat cells (E6, docs/04-exercises.md §3).
public enum Dictation {
    /// The pattern as one library cell per macrobeat, or nil when it can't be written that way
    /// (a pickup, a tie, or a note across a macrobeat boundary).
    public static func cells(for pattern: Pattern, in library: PatternLibrary) -> [Cell]? {
        guard pattern.pickupTicks == 0, !pattern.events.contains(where: { $0.tieToNext || $0.kind == .continuation }) else { return nil }
        return pattern.meter.macrobeatSpans.map { span -> Cell? in
            let tokens = pattern.events
                .filter { $0.startTick >= span.startTick && $0.startTick < span.endTick }
                .map { RhythmToken(ticks: $0.ticks, isRest: $0.kind == .rest) }
            guard tokens.map(\.ticks).reduce(0, +) == span.ticks else { return nil }
            return library.cells(forMacrobeatSize: span.microbeats).first { $0.tokens == tokens }
        }.reduce([Cell]?.some([])) { acc, cell in
            guard let acc, let cell else { return nil }
            return acc + [cell]
        }
    }

    /// The learner's cells as a pattern (nil if a cell doesn't fit its macrobeat).
    public static func pattern(from cells: [Cell], meter: Meter, id: String = "dictation") -> Pattern? {
        guard cells.map(\.macrobeatSize) == meter.macrobeats else { return nil }
        var tick = 0
        var events: [RhythmEvent] = []
        for token in cells.flatMap(\.tokens) {
            events.append(RhythmEvent(startTick: tick, ticks: token.ticks, kind: token.isRest ? .rest : .note, tieToNext: false))
            tick += token.ticks
        }
        return Pattern(id: id, meter: meter, content: cells.map(\.minContent).max() ?? .macroMicro, pickupTicks: 0, events: events)
    }

    /// Index of the first macrobeat that differs from the answer (nil = all right).
    public static func firstDifference(answer: [Cell], written: [Cell?]) -> Int? {
        answer.indices.first { !written.indices.contains($0) || written[$0] != answer[$0] }
    }

    /// Cells to offer: those whose content is in `contents` (combined only in the combined meter),
    /// plus the answer's own cells.
    public static func palette(for meter: Meter, contents: Set<ContentKind>, answer: [Cell], library: PatternLibrary) -> [Cell] {
        var cells: [Cell] = []
        for size in Set(meter.macrobeats).sorted() {
            cells += library.cells(forMacrobeatSize: size).filter {
                (contents.contains($0.minContent) && ($0.minContent != .combined || meter.allowsThirds)) || answer.contains($0)
            }
        }
        return cells
    }
}
