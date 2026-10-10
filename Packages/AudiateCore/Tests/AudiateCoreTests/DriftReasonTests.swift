import Testing
@testable import AudiateCore

/// Without the click the note errors are taken against the learner's own tempo, so they can all be small
/// while the tempo itself changed: that failure must be named as a drift, not as "timing off".
@Suite("Drift reason")
struct DriftReasonTests {
    // 6/8, three eighths and a dotted quarter: eighth 0.32 s, tol 0.08
    let expected = [0.0, 0.32, 0.64, 0.96]

    @Test func steadySlowingWithSmallNoteErrorsIsADrift() {
        let taps = zip(expected, [-0.04, -0.01, 0.015, 0.045]).map { $0 + $1 }
        let g = OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: 1.92, mode: .relative)
        #expect(g.meanAbsError <= 0.5 * g.tolerance)
        #expect(g.drifted)
        #expect(g.errors == [.tempoDrift])
    }

    @Test func absoluteModeNeverDrifts() {
        let g = OnsetGrader.grade(expected: expected, taps: expected.map { $0 * 1.12 }, responseStart: 0, responseEnd: 1.92,
                                  mode: .absolute)
        #expect(!g.drifted)
    }
}
