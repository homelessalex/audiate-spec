import Testing
@testable import AudiateCore

@Suite("Debounce")
struct DebounceTests {
    let expected = [0.0, 0.375, 0.75, 1.125]

    @Test func doubleTriggerIsNotAnExtraTap() {
        let taps = (expected + [0.375 + 0.04]).sorted()   // the second key fired twice, 40 ms apart
        let g = OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: 1.5, mode: .absolute)
        #expect(g.extras.isEmpty)
        #expect(g.passed)
    }

    @Test func fastestRealNotesSurvive() {
        // 6-tick notes of an unusual meter at the top tempo: 232 eighths/min → 129 ms apart
        let ioi = 60.0 / 232 / 2
        #expect(ioi > 2 * OnsetGraderPolicy.debounce)
        #expect(OnsetGrader.debounce([0, ioi, 2 * ioi]).count == 3)
    }
}
