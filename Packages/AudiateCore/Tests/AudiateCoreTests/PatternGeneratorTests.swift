import Testing
@testable import AudiateCore

@Suite("PatternGenerator")
struct PatternGeneratorTests {
    let library = Fixtures.library
    let generator = PatternGenerator(library: Fixtures.library)
    let deriver = SyllableDeriver()

    var meters: [Meter] { library.meters.values.sorted { $0.id < $1.id } }

    /// docs/06 M0 acceptance: 10 000 seeded generations are valid, unfamiliar, respect unlocked content.
    @Test func tenThousandSeededGenerations() throws {
        let familiar = Set(library.patterns.map(\.shape))
        let order = ContentKind.allCases
        var distinct = Set<RhythmShape>()
        var sawTie = false, sawUpbeat = false, sawTriplet = false

        for seed in 0..<10_000 {
            var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
            let meter = meters[seed % meters.count]
            let unlockedCount = 2 + (seed / meters.count) % (order.count - 1)
            let unlocked = Set(order.prefix(unlockedCount))

            let p = try generator.generate(meter: meter, unlocked: unlocked, using: &rng)

            try checkValid(p)
            #expect(!familiar.contains(p.shape), "seed \(seed): \(p.id) is familiar")
            try checkRespects(p, unlocked: unlocked, seed: seed)

            distinct.insert(p.shape)
            sawTie = sawTie || p.events.contains { $0.tieToNext }
            sawUpbeat = sawUpbeat || p.pickupTicks > 0
            sawTriplet = sawTriplet || p.events.contains { $0.ticks == 8 }
        }
        #expect(distinct.count > 300)
        #expect(sawTie && sawUpbeat && sawTriplet)
    }

    @Test func sameSeedSamePattern() throws {
        let meter = try #require(library.meters["unusual_unpaired_2_2_3"])
        let unlocked = Set(ContentKind.allCases)
        func run(_ seed: UInt64) throws -> [String] {
            var rng = SeededRandomNumberGenerator(seed: seed)
            return try (0..<20).map { _ in try generator.generate(meter: meter, unlocked: unlocked, using: &rng).id }
        }
        #expect(try run(42) == run(42))
        #expect(try run(42) != run(43))
    }

    @Test func throwsWhenNoUnfamiliarPatternExists() throws {
        // Duple macro/micro cells give exactly D-MM-01…04, all of which are familiar.
        let duple = try #require(library.meters["usual_duple"])
        var rng = SeededRandomNumberGenerator(seed: 1)
        #expect(throws: GeneratorError.self) {
            try generator.generate(meter: duple, unlocked: [.macroMicro], using: &rng)
        }
    }

    // MARK: - checks (independent of generator internals)

    func checkValid(_ p: Pattern) throws {
        var t = -p.pickupTicks
        for e in p.events {
            #expect(e.startTick == t)
            t += e.ticks
            _ = try NotationMapper.notation(forTicks: e.ticks, in: p.meter)
            _ = try deriver.syllable(in: p.meter, atTick: e.startTick)
        }
        #expect(t == p.meter.measureTicks)
        #expect(p.events.contains { $0.kind == .note })
        #expect(p.events.last?.tieToNext == false)
        for (a, b) in zip(p.events, p.events.dropFirst()) {
            #expect(a.tieToNext == (b.kind == .continuation))
        }
        _ = try NotationLayout(pattern: p)
    }

    func checkRespects(_ p: Pattern, unlocked: Set<ContentKind>, seed: Int) throws {
        #expect(unlocked.contains(p.content))
        if p.pickupTicks > 0 {
            #expect(unlocked.contains(.upbeat))
            #expect(p.pickupTicks == 12 || (p.pickupTicks == 6 && unlocked.contains(.division)))
        }
        if p.events.contains(where: { $0.tieToNext }) { #expect(unlocked.contains(.tie)) }

        // Each body macrobeat must be exactly one allowed cell.
        let body = p.events.filter { $0.startTick >= 0 }
        for span in p.meter.macrobeatSpans {
            let tokens = body
                .filter { $0.startTick >= span.startTick && $0.startTick < span.endTick }
                .map { $0.kind == .rest ? "r\($0.ticks)" : "\($0.ticks)" }
                .joined(separator: " ")
            let allowed = library.cells(forMacrobeatSize: span.microbeats)
                .filter { unlocked.contains($0.minContent) && ($0.minContent != .combined || p.meter.allowsThirds) }
                .map { $0.tokens.map { $0.isRest ? "r\($0.ticks)" : "\($0.ticks)" }.joined(separator: " ") }
            #expect(allowed.contains(tokens), "seed \(seed): \(p.id) macrobeat \(span.index) = \(tokens)")
        }
    }
}
