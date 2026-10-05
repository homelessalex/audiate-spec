/// Builds unfamiliar patterns from macrobeat cells for the inference levels (docs/03-rhythm-model.md §5).
public struct PatternGenerator: Sendable {
    public let library: PatternLibrary
    public var policy: GeneratorPolicy
    public var deriver: SyllableDeriver

    public init(library: PatternLibrary, policy: GeneratorPolicy = .standard, deriver: SyllableDeriver = SyllableDeriver()) {
        self.library = library
        self.policy = policy
        self.deriver = deriver
    }

    public func generate(meter: Meter, unlocked: Set<ContentKind>, using rng: inout some RandomNumberGenerator) throws -> Pattern {
        let options = try meter.macrobeats.map { size in
            let cells = library.cells(forMacrobeatSize: size).filter { isAllowed($0, in: meter, unlocked: unlocked) }
            guard !cells.isEmpty else { throw GeneratorError.noCells(macrobeatSize: size) }
            return cells
        }
        for _ in 0..<policy.maxAttempts {
            if let pattern = candidate(meter: meter, unlocked: unlocked, options: options, using: &rng) {
                return pattern
            }
        }
        throw GeneratorError.noUnfamiliarPattern(meterID: meter.id)
    }

    /// `combined` cells (8 8 8) only make sense in the usual combined meter.
    func isAllowed(_ cell: Cell, in meter: Meter, unlocked: Set<ContentKind>) -> Bool {
        unlocked.contains(cell.minContent) && (cell.minContent != .combined || meter.allowsThirds)
    }

    private func candidate(meter: Meter, unlocked: Set<ContentKind>, options: [[Cell]],
                           using rng: inout some RandomNumberGenerator) -> Pattern? {
        let cells = options.map { pick($0, using: &rng) }
        var bars = cells.map(\.tokens)
        var used = Set(cells.map(\.minContent))
        guard bars.joined().contains(where: { !$0.isRest }) else { return nil }

        if unlocked.contains(.tie), Double.random(in: 0..<1, using: &rng) < policy.tieProbability {
            let boundaries = bars.indices.dropLast().filter { k in
                !bars[k].last!.isRest && !bars[k + 1].first!.isRest
            }
            if let k = boundaries.randomElement(using: &rng) {
                let last = bars[k].removeLast()
                bars[k].append(RhythmToken(ticks: last.ticks, tieToNext: true))
                used.insert(.tie)
            }
        }

        var pickup: [RhythmToken] = []
        if unlocked.contains(.upbeat), Double.random(in: 0..<1, using: &rng) < policy.upbeatProbability {
            let lengths = policy.upbeatTicks.filter { $0 != Rhythm.divisionTicks || unlocked.contains(.division) }
            if let ticks = lengths.randomElement(using: &rng) {
                pickup = [RhythmToken(ticks: ticks)]
                used.insert(.upbeat)
            }
        }

        let tokens = pickup + bars.joined()
        let pattern = Pattern(
            id: "GEN:\(meter.id):" + pickup.map(\.description).joined(separator: " ") + "|"
                + bars.map { $0.map(\.description).joined(separator: " ") }.joined(separator: " | "),
            meter: meter,
            content: used.max()!,
            pickupTicks: pickup.map(\.ticks).reduce(0, +),
            events: events(from: tokens, startingAt: -pickup.map(\.ticks).reduce(0, +))
        )
        guard (try? PatternValidator.validate(pattern, deriver: deriver)) != nil,
              !library.isFamiliar(pattern.shape) else { return nil }
        return pattern
    }

    private func events(from tokens: [RhythmToken], startingAt start: Int) -> [RhythmEvent] {
        var tick = start
        var tiedInto = false
        return tokens.map { token in
            defer { tick += token.ticks; tiedInto = token.tieToNext }
            let kind: EventKind = token.isRest ? .rest : (tiedInto ? .continuation : .note)
            return RhythmEvent(startTick: tick, ticks: token.ticks, kind: kind, tieToNext: token.tieToNext)
        }
    }

    private func pick(_ cells: [Cell], using rng: inout some RandomNumberGenerator) -> Cell {
        let total = cells.map(policy.weight(of:)).reduce(0, +)
        var r = Double.random(in: 0..<total, using: &rng)
        for cell in cells {
            r -= policy.weight(of: cell)
            if r < 0 { return cell }
        }
        return cells[cells.count - 1]
    }
}
