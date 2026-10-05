/// Wrong answers for "Name the syllables" (docs/04-exercises.md §4): same meter, one onset moved,
/// added or removed; every distractor is a valid pattern whose syllable line differs from the target's.
/// When that gives too few (a single long note, triplets), one macrobeat is swapped for another cell.
public enum DistractorGenerator {
    public static func distractors(for pattern: Pattern, library: PatternLibrary, count: Int = 3,
                                   deriver: SyllableDeriver = SyllableDeriver(),
                                   using rng: inout some RandomNumberGenerator) -> [Pattern] {
        let target = Body(pattern)
        var candidates: [Body] = []
        for onset in target.onsets {
            candidates.append(target.removing(onset))
            for position in target.positions where position != onset {
                candidates.append(target.removing(onset).adding(position))
            }
        }
        for position in target.positions {
            candidates.append(target.adding(position))
        }
        candidates.shuffle(using: &rng)

        var swaps: [Body] = []
        for span in pattern.meter.macrobeatSpans {
            for cell in library.cells(forMacrobeatSize: span.microbeats) where target.accepts(cell) {
                swaps.append(target.replacing(span, with: cell))
            }
        }
        candidates += swaps.shuffled(using: &rng)

        var lines: Set<String> = [(try? deriver.line(for: pattern)) ?? ""]
        var result: [Pattern] = []
        for candidate in candidates where result.count < count {
            guard let p = candidate.pattern(from: pattern, index: result.count),
                  (try? PatternValidator.validate(p, deriver: deriver)) != nil,
                  let line = try? deriver.line(for: p), lines.insert(line).inserted else { continue }
            result.append(p)
        }
        return result
    }

    /// The measure body as one state per tick; the pickup is kept as is.
    struct Body {
        enum Tick: Equatable { case onset, sustain, rest }

        let ticks: [Tick]
        let meter: Meter
        let allowsRests: Bool
        let step: Int

        init(_ pattern: Pattern) {
            var ticks: [Tick] = []
            for event in pattern.events where event.startTick >= 0 {
                let first: Tick = event.kind == .note ? .onset : (event.kind == .rest ? .rest : .sustain)
                ticks.append(first)
                ticks += Array(repeating: event.kind == .rest ? .rest : .sustain, count: event.ticks - 1)
            }
            self.ticks = ticks
            meter = pattern.meter
            allowsRests = pattern.events.contains { $0.kind == .rest }
            let usesDivisions = pattern.events.contains { $0.ticks % Rhythm.ticksPerMicrobeat == Rhythm.divisionTicks
                || $0.startTick.floorMod(Rhythm.ticksPerMicrobeat) == Rhythm.divisionTicks }
            step = usesDivisions ? Rhythm.divisionTicks : Rhythm.ticksPerMicrobeat
        }

        private init(ticks: [Tick], from other: Body) {
            self.ticks = ticks
            meter = other.meter
            allowsRests = other.allowsRests
            step = other.step
        }

        var onsets: [Int] { ticks.indices.filter { ticks[$0] == .onset } }

        /// Grid points a new onset may go to (thirds too in the combined meter).
        var positions: [Int] {
            var p = Set(stride(from: 0, to: ticks.count, by: step))
            if meter.allowsThirds {
                for span in meter.macrobeatSpans where span.microbeats == 2 {
                    p.insert(span.startTick + Rhythm.thirdTicks)
                    p.insert(span.startTick + 2 * Rhythm.thirdTicks)
                }
            }
            return p.sorted()
        }

        /// The removed note's time joins the previous note (or becomes a rest if rests are in play).
        func removing(_ onset: Int) -> Body {
            var t = ticks
            let previous = onset > 0 ? t[onset - 1] : .rest
            if previous != .rest {
                t[onset] = .sustain
            } else if allowsRests {
                var i = onset
                repeat { t[i] = .rest; i += 1 } while i < t.count && t[i] == .sustain
            } else {
                return self
            }
            return Body(ticks: t, from: self)
        }

        /// Splits a note at `position`; inside a rest only when rests are in play.
        func adding(_ position: Int) -> Body {
            var t = ticks
            switch t[position] {
            case .onset: return self
            case .sustain: t[position] = .onset
            case .rest:
                guard allowsRests else { return self }
                t[position] = .onset
                var i = position + 1
                while i < t.count && t[i] == .rest { t[i] = .sustain; i += 1 }
            }
            return Body(ticks: t, from: self)
        }

        /// Cells that bring nothing the target doesn't already use (no rests or triplets out of nowhere).
        func accepts(_ cell: Cell) -> Bool {
            if cell.tokens.contains(where: \.isRest) && !allowsRests { return false }
            if cell.minContent == .combined && !meter.allowsThirds { return false }
            if step == Rhythm.ticksPerMicrobeat && cell.tokens.contains(where: { $0.ticks % Rhythm.ticksPerMicrobeat == Rhythm.divisionTicks }) {
                return false
            }
            return true
        }

        func replacing(_ span: MacrobeatSpan, with cell: Cell) -> Body {
            var t = ticks
            var i = span.startTick
            for token in cell.tokens {
                t[i] = token.isRest ? .rest : .onset
                for k in 1..<token.ticks { t[i + k] = token.isRest ? .rest : .sustain }
                i += token.ticks
            }
            // a note that sustained into the next macrobeat can't continue a rest: it gets its own onset
            if i < t.count, t[i] == .sustain, t[i - 1] == .rest { t[i] = .onset }
            return Body(ticks: t, from: self)
        }

        func pattern(from original: Pattern, index: Int) -> Pattern? {
            guard ticks.contains(.onset) else { return nil }
            var events = original.events.filter { $0.startTick < 0 }
            var start = 0
            while start < ticks.count {
                let isRest = ticks[start] == .rest
                var end = start + 1
                while end < ticks.count && (isRest ? ticks[end] == .rest : ticks[end] == .sustain) { end += 1 }
                // a body that begins with a sustain continues the pickup's last note
                let kind: EventKind = isRest ? .rest : (ticks[start] == .onset ? .note : .continuation)
                if kind == .continuation {
                    guard let last = events.popLast(), last.kind != .rest else { return nil }
                    events.append(RhythmEvent(startTick: last.startTick, ticks: last.ticks, kind: last.kind, tieToNext: true))
                }
                events.append(RhythmEvent(startTick: start, ticks: end - start, kind: kind, tieToNext: false))
                start = end
            }
            return Pattern(id: "\(original.id)~\(index)", meter: original.meter, content: original.content,
                           pickupTicks: original.pickupTicks, events: events)
        }
    }
}
