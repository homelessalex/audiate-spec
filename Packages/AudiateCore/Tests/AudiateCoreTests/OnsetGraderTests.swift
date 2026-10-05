import Testing
@testable import AudiateCore

/// docs/04-exercises.md §2 and docs/05-architecture.md §8, table-driven over patterns.json.
@Suite("OnsetGrader")
struct OnsetGraderTests {
    struct Case {
        let slot: ResponseSlot
        var expected: [Double] { slot.expectedOnsets }
        var tolerance: Double { OnsetGrader.tolerance(expected: expected, responseStart: slot.start, responseEnd: slot.end) }

        func grade(_ taps: [Double], _ mode: TimingMode = .absolute) -> OnsetGrade {
            OnsetGrader.grade(expected: expected, taps: taps, responseStart: slot.start, responseEnd: slot.end, mode: mode)
        }
    }

    static func makeCase(_ raw: RawPattern) throws -> Case {
        let p = Fixtures.pattern(raw.id)
        let t = try Timeline.echoBlock(patterns: [p], tempo: .standard(for: p.meter), clickStage: .b)
        return Case(slot: t.responses[0])
    }

    @Test(arguments: Fixtures.rawPatterns)
    func perfectTapsPass(raw: RawPattern) throws {
        let c = try Self.makeCase(raw)
        for mode in [TimingMode.absolute, .relative] {
            let g = c.grade(c.expected, mode)
            #expect(g.passed, "\(mode)")
            #expect(g.hits.count == c.expected.count)
            #expect(g.accuracy == 1)
        }
    }

    @Test(arguments: Fixtures.rawPatterns)
    func singleTapOutsideToleranceFails(raw: RawPattern) throws {
        let c = try Self.makeCase(raw)
        let k = c.expected.count / 2
        for sign in [1.0, -1.0] {
            var taps = c.expected
            taps[k] += sign * (c.tolerance + 0.001)
            #expect(!c.grade(taps).passed, "shift \(sign)")
        }
    }

    @Test(arguments: Fixtures.rawPatterns)
    func missingTapFails(raw: RawPattern) throws {
        let c = try Self.makeCase(raw)
        var taps = c.expected
        taps.remove(at: taps.count / 2)
        let g = c.grade(taps)
        #expect(!g.passed)
        #expect(g.misses.count == 1)
    }

    @Test(arguments: Fixtures.rawPatterns)
    func extraTapFails(raw: RawPattern) throws {
        let c = try Self.makeCase(raw)
        // middle of the largest gap (including the gap to the end of the response)
        let points = c.expected + [c.slot.end]
        let gap = zip(points, points.dropFirst()).max { ($0.1 - $0.0) < ($1.1 - $1.0) }!
        let g = c.grade((c.expected + [(gap.0 + gap.1) / 2]).sorted())
        #expect(!g.passed)
        #expect(g.extras.count == 1)
        #expect(g.hits.count == c.expected.count)
    }

    @Test(arguments: Fixtures.rawPatterns.filter { $0.events.filter { $0.kind == "note" }.count >= 3 })
    func relativeModeAcceptsFivePercentTempoChangeButNotTen(raw: RawPattern) throws {
        let c = try Self.makeCase(raw)
        let e0 = c.expected[0]
        func scaled(_ r: Double) -> [Double] { c.expected.map { e0 + ($0 - e0) * r } }
        for r in [1.05, 0.95] {
            let g = c.grade(scaled(r), .relative)
            #expect(g.passed, "ratio \(r)")
            #expect(abs((g.tempoRatio ?? 0) - r) < 1e-6)
        }
        for r in [1.10, 0.90] {
            #expect(!c.grade(scaled(r), .relative).passed, "ratio \(r)")
        }
    }

    @Test func relativeModeIgnoresConstantOffsetAbsoluteDoesNot() throws {
        let c = try Self.makeCase(Fixtures.rawPatterns.first { $0.id == "D-MM-04" }!)
        let late = c.expected.map { $0 + 0.1 }
        #expect(c.grade(late, .relative).passed)
        #expect(!c.grade(late, .absolute).passed)
    }

    @Test func toleranceAndWindowFollowTheSpec() {
        // minIOI 0.1875 s → tol = clamp(0.046875, 0.035, 0.080), pre = min(0.12, 0.09375)
        let expected = [3.0, 3.1875, 3.375, 3.5625, 3.75]
        #expect(OnsetGrader.tolerance(expected: expected, responseStart: 3, responseEnd: 4.5) == 0.046875)
        #expect(OnsetGrader.tolerance(expected: [0, 1], responseStart: 0, responseEnd: 2) == 0.080)
        #expect(OnsetGrader.tolerance(expected: [0, 0.1], responseStart: 0, responseEnd: 2) == 0.035)
        // single onset: minIOI falls back to the response length
        #expect(OnsetGrader.tolerance(expected: [0], responseStart: 0, responseEnd: 1.5) == 0.080)

        // a tap before start − pre is ignored (counts as neither extra nor hit)
        let g = OnsetGrader.grade(expected: expected, taps: [2.8] + expected, responseStart: 3, responseEnd: 4.5, mode: .absolute)
        #expect(g.passed)
        #expect(g.extras.isEmpty)
    }

    @Test func doubleTapsAreDebounced() {
        let expected = [0.0, 0.75]
        let g = OnsetGrader.grade(expected: expected, taps: [0.0, 0.02, 0.75], responseStart: 0, responseEnd: 1.5, mode: .absolute)
        #expect(g.passed)
        #expect(g.extras.isEmpty)
    }

    @Test func accuracyCountsExtras() {
        let expected = [0.0, 0.375, 0.75, 1.125]
        let g = OnsetGrader.grade(expected: expected, taps: [0.0, 0.375, 0.6, 0.75], responseStart: 0, responseEnd: 1.5, mode: .absolute)
        #expect(g.hits.count == 3)
        #expect(g.misses == [1.125])
        #expect(g.extras == [0.6])
        #expect(g.accuracy == 3.0 / 5.0)
    }

    @Test func matchingPrefersMoreHitsOverSmallerError() {
        // tap at 0.4 could pair with 0.375; the DP must still pair 0.0 and 0.75 too
        let g = OnsetGrader.grade(expected: [0.0, 0.375, 0.75], taps: [0.01, 0.4, 0.74], responseStart: 0, responseEnd: 1.5, mode: .absolute)
        #expect(g.hits.map(\.expected) == [0.0, 0.375, 0.75])
        #expect(abs(g.meanAbsError - 0.015) < 1e-9)
    }
}
