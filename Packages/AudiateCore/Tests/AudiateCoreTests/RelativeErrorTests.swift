import Testing
@testable import AudiateCore

/// Without the click the grader fits the learner's own tempo and phase; that fit must not swallow the
/// timing errors it is there to measure (a plain two-parameter fit read 0 ms for any two-note answer).
@Suite("Relative-mode error")
struct RelativeErrorTests {
    func grade(_ expected: [Double], _ taps: [Double], mode: TimingMode = .relative, end: Double = 1.5) -> OnsetGrade {
        OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: end, mode: mode)
    }

    @Test func twoNotesKeepTheirError() {
        let g = grade([0, 0.75], [0.03, 0.72])
        #expect(g.meanAbsError > 0.025)
    }

    @Test(arguments: [2, 3, 4, 6, 8])
    func unevenTapsReadAboutAsUnevenAsWithTheClick(notes: Int) {
        let expected = (0..<notes).map { Double($0) * 1.5 / Double(notes) }
        let jitter = [0.025, -0.02, 0.015, -0.025, 0.02, -0.015, 0.025, -0.02]
        let taps = zip(expected, jitter).map { $0 + $1 }
        let relative = grade(expected, taps).meanAbsError, absolute = grade(expected, taps, mode: .absolute).meanAbsError
        #expect(relative >= 0.8 * absolute, "relative \(relative) vs absolute \(absolute)")
    }

    @Test func steadySlowingIsStillForgiven() {
        let expected = (0..<8).map { Double($0) * 0.1875 }
        let g = grade(expected, expected.map { $0 * 1.05 })
        #expect(g.passed)
        #expect(g.meanAbsError < 0.005)
        #expect(abs((g.tempoRatio ?? 0) - 1.05) < 1e-6)
    }

    @Test func twoHandPulseInTwoFourIsGraded() {
        // left hand in 2/4: two macrobeats, the second 70 ms late
        let slot = ResponseSlot(patternID: "x", start: 0, end: 1.5, expectedOnsets: [0, 0.375, 0.75], macrobeatTimes: [0, 0.75])
        let g = TwoHandGrade.grade(slot: slot, rhythmTaps: [0, 0.375, 0.75], pulseTaps: [0, 0.82], mode: .relative)
        #expect(g.pulse.meanAbsError > 0.03)
        #expect(!g.passed)
    }
}
