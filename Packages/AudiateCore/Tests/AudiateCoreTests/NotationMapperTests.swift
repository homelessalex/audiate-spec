import Testing
@testable import AudiateCore

@Suite("NotationMapper")
struct NotationMapperTests {
    @Test(arguments: [
        (72, NoteValue.half, 1, Int?.none),
        (48, .half, 0, nil),
        (36, .quarter, 1, nil),
        (24, .quarter, 0, nil),
        (18, .eighth, 1, nil),
        (12, .eighth, 0, nil),
        (6, .sixteenth, 0, nil),
    ])
    func table(ticks: Int, value: NoteValue, dots: Int, tuplet: Int?) throws {
        let triple = try #require(Fixtures.library.meters["usual_triple"])
        #expect(try NotationMapper.notation(forTicks: ticks, in: triple)
                == NotationValue(value: value, dots: dots, tuplet: tuplet))
    }

    @Test func tripletOnlyInCombinedMeter() throws {
        let combined = try #require(Fixtures.library.meters["usual_combined"])
        let duple = try #require(Fixtures.library.meters["usual_duple"])
        #expect(try NotationMapper.notation(forTicks: 8, in: combined)
                == NotationValue(value: .eighth, dots: 0, tuplet: 3))
        #expect(throws: RhythmError.self) { try NotationMapper.notation(forTicks: 8, in: duple) }
    }

    @Test func unnotatableDurationsThrow() throws {
        let duple = try #require(Fixtures.library.meters["usual_duple"])
        for ticks in [0, 3, 10, 30, 60] {
            #expect(throws: RhythmError.self) { try NotationMapper.notation(forTicks: ticks, in: duple) }
        }
    }
}
