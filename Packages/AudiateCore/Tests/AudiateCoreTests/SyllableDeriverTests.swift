import Testing
@testable import AudiateCore

@Suite("SyllableDeriver")
struct SyllableDeriverTests {
    let deriver = SyllableDeriver()

    func meter(_ id: String) throws -> Meter {
        try #require(Fixtures.library.meters[id])
    }

    func syllables(_ meterID: String, ticks: [Int]) throws -> [String] {
        let m = try meter(meterID)
        return try ticks.map { try deriver.syllable(in: m, atTick: $0) }
    }

    /// Examples from docs/01-methodology.md §3.
    @Test(arguments: [
        ("usual_duple", [0, 12, 24, 36], "Du de Du de"),
        ("usual_duple", [0, 6, 12, 18], "Du ta de ta"),
        ("usual_triple", [0, 12, 24], "Du da di"),
        ("usual_triple", [0, 6, 12, 18, 24, 30], "Du ta da ta di ta"),
        ("unusual_paired_2_3", [0, 12, 24, 36, 48], "Du be Du ba bi"),
        ("unusual_unpaired_2_2_3", [0, 12, 24, 36, 48, 60, 72], "Du be Du be Du ba bi"),
        ("unusual_unpaired_3_2_2", [0, 12, 24, 36, 48, 60, 72], "Du ba bi Du be Du be"),
        ("usual_combined", [0, 8, 16, 24, 36], "Du da di Du de"),
    ])
    func methodologyExamples(meterID: String, ticks: [Int], expected: String) throws {
        #expect(try syllables(meterID, ticks: ticks).joined(separator: " ") == expected)
    }

    @Test func pickupTicksWrapIntoPreviousMeasure() throws {
        #expect(try syllables("usual_duple", ticks: [-12, -6]) == ["de", "ta"])
        #expect(try syllables("usual_triple", ticks: [-12]) == ["di"])
    }

    @Test func offGridTicksThrow() throws {
        let duple = try meter("usual_duple")
        #expect(throws: RhythmError.self) { try deriver.syllable(in: duple, atTick: 3) }
        // thirds exist only in the combined meter
        #expect(throws: RhythmError.self) { try deriver.syllable(in: duple, atTick: 8) }
        let triple = try meter("usual_triple")
        #expect(throws: RhythmError.self) { try deriver.syllable(in: triple, atTick: 8) }
    }

    @Test func displayFormsPerEventKind() throws {
        let duple = try meter("usual_duple")
        let note = RhythmEvent(startTick: 12, ticks: 12, kind: .note, tieToNext: false)
        let rest = RhythmEvent(startTick: 12, ticks: 12, kind: .rest, tieToNext: false)
        let cont = RhythmEvent(startTick: 12, ticks: 12, kind: .continuation, tieToNext: false)
        #expect(try deriver.display(for: note, in: duple) == "de")
        #expect(try deriver.display(for: rest, in: duple) == "(de)")
        #expect(try deriver.display(for: cont, in: duple) == "[de]")
    }

    @Test func tableIsSwappable() throws {
        var table = SyllableTable.standard
        table.unusualDuple = ["Du", "de"]
        let custom = SyllableDeriver(table: table)
        let m = try meter("unusual_paired_2_3")
        #expect(try custom.syllable(in: m, atTick: 12) == "de")
        #expect(try deriver.syllable(in: m, atTick: 12) == "be")
    }
}
