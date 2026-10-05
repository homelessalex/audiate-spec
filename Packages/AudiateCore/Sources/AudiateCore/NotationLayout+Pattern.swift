extension NotationLayout {
    public init(pattern: Pattern, metrics: Metrics = .standard) throws {
        let meter = pattern.meter
        var items: [Item] = []
        var barlines: [Barline] = []
        var x = metrics.leadingWidth

        for (i, event) in pattern.events.enumerated() {
            if event.startTick == 0, pattern.pickupTicks > 0 {
                barlines.append(Barline(x: x, isFinal: false))
                x += metrics.barlineSpacing
            }
            let notation = try NotationMapper.notation(forTicks: event.ticks, in: meter)
            let isNote = event.kind != .rest
            let slot = max(metrics.minSlotWidth, Double(event.ticks) * metrics.pointsPerTick)
            let beamCount = isNote ? notation.value.beamCount : 0
            items.append(Item(
                eventIndex: i, startTick: event.startTick, ticks: event.ticks, x: x, slotWidth: slot, glyph: isNote ? .note : .rest, notation: notation,
                macrobeatIndex: meter.macrobeat(containing: event.startTick).index,
                isPickup: pattern.isPickup(event), beamCount: beamCount, flagCount: beamCount
            ))
            x += slot
        }
        x += metrics.finalBarlineGap
        barlines.append(Barline(x: x, isFinal: true))

        let beams = Self.beamGroups(items: items, pattern: pattern)
        for index in beams.flatMap(\.itemIndices) {
            items[index].flagCount = 0
        }

        self.init(
            timeSignature: meter.timeSignature,
            timeSignatureX: metrics.timeSignatureX,
            items: items,
            beams: beams,
            ties: pattern.events.indices.filter { pattern.events[$0].tieToNext }.map { Tie(fromItem: $0, toItem: $0 + 1) },
            tuplets: try Self.tuplets(pattern: pattern),
            barlines: barlines,
            width: x + metrics.trailingWidth
        )
    }

    /// x of a measure-relative tick (pickup ticks are negative), interpolated inside the event's slot;
    /// used to draw a playhead and tap markers on the staff.
    public func x(forTick tick: Double) -> Double {
        guard let first = items.first, let last = items.last else { return 0 }
        if tick <= Double(first.startTick) { return first.x }
        for item in items where tick < Double(item.startTick + item.ticks) {
            return item.x + (tick - Double(item.startTick)) / Double(item.ticks) * item.slotWidth
        }
        return last.x + last.slotWidth
    }

    /// Consecutive notes of value ≤ eighth lying inside the same macrobeat; rests and the barline break beams.
    static func beamGroups(items: [Item], pattern: Pattern) -> [BeamGroup] {
        var groups: [BeamGroup] = []
        var current: [Int] = []
        func flush() {
            if current.count >= 2 { groups.append(BeamGroup(itemIndices: current)) }
            current = []
        }
        for (i, item) in items.enumerated() {
            let event = pattern.events[i]
            let insideOneMacrobeat = pattern.meter.macrobeat(containing: event.endTick - 1).index == item.macrobeatIndex
            guard item.beamCount > 0, insideOneMacrobeat else {
                flush()
                continue
            }
            if let last = current.last,
               items[last].macrobeatIndex != item.macrobeatIndex || items[last].isPickup != item.isPickup {
                flush()
            }
            current.append(i)
        }
        flush()
        return groups
    }

    /// Runs of triplet members filling one macrobeat (3 × 8 ticks).
    static func tuplets(pattern: Pattern) throws -> [Tuplet] {
        let groupTicks = Rhythm.thirdTicks * 3
        var result: [Tuplet] = []
        var current: [Int] = []
        var sum = 0
        for (i, event) in pattern.events.enumerated() {
            guard try NotationMapper.notation(forTicks: event.ticks, in: pattern.meter).tuplet == 3 else {
                if !current.isEmpty { throw RhythmError.incompleteTuplet(patternID: pattern.id, eventIndex: i) }
                continue
            }
            current.append(i)
            sum += event.ticks
            if sum == groupTicks {
                result.append(Tuplet(itemIndices: current, number: 3))
                current = []
                sum = 0
            }
        }
        if let first = current.first { throw RhythmError.incompleteTuplet(patternID: pattern.id, eventIndex: first) }
        return result
    }
}
