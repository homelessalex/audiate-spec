import Testing
@testable import AudiateCore

/// Every pattern in data/patterns.json must be reproduced exactly by the Swift model:
/// syllables are derived (never read from JSON), notation and difficulty are re-computed.
@Suite("patterns.json reproduction")
struct LibraryReproductionTests {
    let deriver = SyllableDeriver()

    @Test func libraryHas66Patterns() {
        #expect(Fixtures.rawPatterns.count == 66)
        #expect(Fixtures.library.patterns.count == 66)
        #expect(Fixtures.library.patterns.map(\.id) == Fixtures.rawPatterns.map(\.id))
    }

    @Test(arguments: Fixtures.rawPatterns)
    func modelMatchesJSON(raw: RawPattern) throws {
        let p = try #require(Fixtures.library.pattern(id: raw.id))
        #expect(p.meter.id == raw.meter)
        #expect(p.content.rawValue == raw.content)
        #expect(p.meter.macrobeats == raw.macrobeats)
        #expect(p.meter.timeSignature.description == raw.timeSignature)
        #expect(p.measureTicks == raw.measureTicks)
        #expect(p.pickupTicks == raw.pickupTicks)
        #expect(p.events.count == raw.events.count)
    }

    @Test(arguments: Fixtures.rawPatterns)
    func measureSums(raw: RawPattern) throws {
        let p = try #require(Fixtures.library.pattern(id: raw.id))
        let body = p.events.filter { $0.startTick >= 0 }.map(\.ticks).reduce(0, +)
        let pickup = p.events.filter { $0.startTick < 0 }.map(\.ticks).reduce(0, +)
        #expect(body == p.meter.measureTicks)
        #expect(pickup == p.pickupTicks)
    }

    @Test(arguments: Fixtures.rawPatterns)
    func syllablesMatchJSON(raw: RawPattern) throws {
        let p = try #require(Fixtures.library.pattern(id: raw.id))
        #expect(try deriver.line(for: p) == raw.syllables)
        for (event, rawEvent) in zip(p.events, raw.events) {
            #expect(try deriver.syllable(in: p.meter, atTick: event.startTick) == rawEvent.syllable)
            #expect(try deriver.display(for: event, in: p.meter) == rawEvent.syllableDisplay)
        }
    }

    @Test(arguments: Fixtures.rawPatterns)
    func eventsAndNotationMatchJSON(raw: RawPattern) throws {
        let p = try #require(Fixtures.library.pattern(id: raw.id))
        for (event, rawEvent) in zip(p.events, raw.events) {
            #expect(event.startTick == rawEvent.startTick)
            #expect(event.ticks == rawEvent.ticks)
            #expect(event.kind.rawValue == rawEvent.kind)
            #expect(event.tieToNext == rawEvent.tieToNext)
            #expect(p.isPickup(event) == rawEvent.isPickup)
            let n = try NotationMapper.notation(forTicks: event.ticks, in: p.meter)
            #expect(n.value.rawValue == rawEvent.notation.value)
            #expect(n.dots == rawEvent.notation.dots)
            #expect(n.tuplet == rawEvent.notation.tuplet)
        }
    }

    @Test(arguments: Fixtures.rawPatterns)
    func difficultyMatchesJSON(raw: RawPattern) throws {
        let p = try #require(Fixtures.library.pattern(id: raw.id))
        let score = DifficultyScorer.score(p)
        #expect(abs(score - raw.difficultyScore) < 0.005, "score \(score) vs \(raw.difficultyScore)")
        #expect(DifficultyScorer.level(p).rawValue == raw.difficulty)
    }
}
