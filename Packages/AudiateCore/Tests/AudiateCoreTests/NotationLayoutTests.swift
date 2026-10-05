import Testing
@testable import AudiateCore

@Suite("NotationLayout")
struct NotationLayoutTests {
    func layout(_ id: String) throws -> NotationLayout {
        try NotationLayout(pattern: Fixtures.pattern(id))
    }

    @Test(arguments: Fixtures.rawPatterns)
    func invariantsHoldForEveryPattern(raw: RawPattern) throws {
        let p = Fixtures.pattern(raw.id)
        let l = try NotationLayout(pattern: p)
        let metrics = NotationLayout.Metrics.standard

        #expect(l.items.count == p.events.count)
        #expect(l.items.map(\.eventIndex) == Array(p.events.indices))
        for (a, b) in zip(l.items, l.items.dropFirst()) {
            #expect(a.x + a.slotWidth <= b.x)
        }
        #expect(l.items.allSatisfy { $0.slotWidth >= metrics.minSlotWidth })

        let tieSources = p.events.indices.filter { p.events[$0].tieToNext }
        #expect(l.ties.map(\.fromItem) == tieSources)
        #expect(l.ties.allSatisfy { $0.toItem == $0.fromItem + 1 && p.events[$0.toItem].kind == .continuation })

        for beam in l.beams {
            #expect(beam.itemIndices.count >= 2)
            #expect(beam.itemIndices == Array(beam.itemIndices.first!...beam.itemIndices.last!))
            #expect(beam.itemIndices.allSatisfy { l.items[$0].glyph == .note && l.items[$0].flagCount == 0 })
            #expect(Set(beam.itemIndices.map { l.items[$0].macrobeatIndex }).count == 1)
            #expect(Set(beam.itemIndices.map { l.items[$0].isPickup }).count == 1)
        }
        let beamed = Set(l.beams.flatMap(\.itemIndices))
        for (i, item) in l.items.enumerated() where !beamed.contains(i) {
            #expect(item.flagCount == (item.glyph == .note ? item.beamCount : 0))
        }

        for tuplet in l.tuplets {
            #expect(tuplet.number == 3)
            #expect(tuplet.itemIndices.map { p.events[$0].ticks }.reduce(0, +) == 24)
        }
        let tupletEvents = p.events.indices.filter { p.events[$0].ticks == 8 }
        #expect(l.tuplets.flatMap(\.itemIndices) == tupletEvents)

        #expect(l.barlines.count == (p.pickupTicks > 0 ? 2 : 1))
        #expect(l.barlines.last?.isFinal == true)
        #expect(l.width > (l.barlines.last?.x ?? 0))
        #expect(l.timeSignature == p.meter.timeSignature)
    }

    @Test(arguments: [
        ("D-MM-04", [[0, 1], [2, 3]]),
        ("T-MM-04", [[0, 1, 2], [3, 4, 5]]),
        ("D-DV-03", [[0, 1, 2, 3]]),
        ("D-RS-03", [[2, 3]]),
        ("D-EL-04", [[0, 1]]),
        ("D-EL-06", [[0, 1, 2]]),
        ("T-EL-01", []),
        ("T-TI-02", [[0, 1, 2], [3, 4, 5]]),
        ("C-MM-03", [[0, 1, 2], [3, 4]]),
        ("D-UB-02", [[0, 1]]),
        ("UU-MM-02", [[0, 1], [2, 3], [4, 5, 6]]),
    ])
    func beamGroups(id: String, expected: [[Int]]) throws {
        #expect(try layout(id).beams.map(\.itemIndices) == expected)
    }

    @Test func unbeamedShortNotesGetFlags() throws {
        let rs = try layout("D-RS-03") // 12 r12 12 12
        #expect(rs.items.map(\.flagCount) == [1, 0, 0, 0])
        let el = try layout("T-EL-01") // 24 12 36
        #expect(el.items.map(\.flagCount) == [0, 1, 0])
    }

    @Test func sixteenthsCarryTwoBeams() throws {
        #expect(try layout("D-EL-04").items.map(\.beamCount) == [1, 2, 0])
    }

    @Test func tupletsAndTies() throws {
        #expect(try layout("C-MM-01").tuplets.map(\.itemIndices) == [[0, 1, 2]])
        #expect(try layout("C-MM-04").tuplets.map(\.itemIndices) == [[2, 3, 4]])
        let tie = try layout("D-TI-01")
        #expect(tie.ties.map { [$0.fromItem, $0.toItem] } == [[1, 2]])
    }

    @Test func pickupGetsBarlineBeforeTheMeasure() throws {
        let l = try layout("D-UB-01") // pickup 12 | 24 24
        #expect(l.barlines.count == 2)
        #expect(l.barlines[0].x > l.items[0].x)
        #expect(l.barlines[0].x <= l.items[1].x)
        #expect(l.items.map(\.isPickup) == [true, false, false])
    }

    @Test func spacingIsProportionalToDuration() throws {
        let l = try layout("D-EL-02") // 36 12
        #expect(l.items[0].slotWidth > l.items[1].slotWidth)
        let even = try layout("D-MM-01")
        #expect(even.items[0].slotWidth == even.items[1].slotWidth)
    }
}
