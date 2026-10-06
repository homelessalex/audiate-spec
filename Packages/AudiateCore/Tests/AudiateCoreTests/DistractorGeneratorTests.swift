import Testing
@testable import AudiateCore

@Suite("DistractorGenerator")
struct DistractorGeneratorTests {
    let deriver = SyllableDeriver()

    @Test(arguments: Fixtures.rawPatterns)
    func threeValidDistinctDistractors(raw: RawPattern) throws {
        let target = Fixtures.pattern(raw.id)
        var rng = SeededRandomNumberGenerator(seed: 7)
        let distractors = DistractorGenerator.distractors(for: target, library: Fixtures.library, using: &rng)
        #expect(distractors.count == 3)
        #expect(Set(distractors.map(\.shape) + [target.shape]).count == 4) // all sound different
        for d in distractors { _ = try NotationLayout(pattern: d) }
        for d in distractors {
            try PatternValidator.validate(d, deriver: deriver)
            #expect(d.meter == target.meter)
            #expect(d.pickupTicks == target.pickupTicks)
            #expect(d.shape != target.shape)
            // differs within one macrobeat at most (one onset moved/added/removed, or one cell swapped)
            let a = Set(target.onsets.map(\.startTick)), b = Set(d.onsets.map(\.startTick))
            let changed = a.symmetricDifference(b).map { target.meter.macrobeat(containing: $0).index }
            #expect(Set(changed).count <= 2)
        }
    }

    @Test func noRestsInventedForPatternsWithoutRests() {
        var rng = SeededRandomNumberGenerator(seed: 1)
        for id in ["D-MM-01", "D-MM-04", "T-MM-02", "D-EL-01"] {
            let ds = DistractorGenerator.distractors(for: Fixtures.pattern(id), library: Fixtures.library, using: &rng)
            #expect(ds.allSatisfy { !$0.events.contains { $0.kind == .rest } }, "\(id)")
        }
    }
}
