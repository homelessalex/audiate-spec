/// Structural checks shared by the library loader and the generator.
enum PatternValidator {
    static func validate(_ pattern: Pattern, deriver: SyllableDeriver) throws {
        let id = pattern.id
        var tick = -pattern.pickupTicks
        var sawBarline = pattern.pickupTicks == 0
        for (i, event) in pattern.events.enumerated() {
            guard event.startTick == tick, event.ticks > 0 else {
                throw RhythmError.eventsNotContiguous(patternID: id, atTick: event.startTick)
            }
            if event.startTick == 0 { sawBarline = true }
            _ = try NotationMapper.notation(forTicks: event.ticks, in: pattern.meter)
            _ = try deriver.syllable(in: pattern.meter, atTick: event.startTick)
            let tiedInto = i > 0 && pattern.events[i - 1].tieToNext
            guard (event.kind == .continuation) == tiedInto, !(event.tieToNext && event.kind == .rest) else {
                throw RhythmError.invalidTie(patternID: id, eventIndex: i)
            }
            tick += event.ticks
        }
        guard pattern.pickupTicks >= 0, pattern.pickupTicks < pattern.measureTicks, sawBarline else {
            throw RhythmError.pickupNotAtBarline(patternID: id)
        }
        guard tick == pattern.measureTicks else {
            throw RhythmError.measureLengthMismatch(patternID: id, expected: pattern.measureTicks, actual: tick)
        }
        if let last = pattern.events.indices.last, pattern.events[last].tieToNext {
            throw RhythmError.invalidTie(patternID: id, eventIndex: last)
        }
    }
}
