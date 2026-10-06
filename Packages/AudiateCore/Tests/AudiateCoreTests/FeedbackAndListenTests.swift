import Testing
@testable import AudiateCore

@Suite("Feedback and listen blocks")
struct FeedbackAndListenTests {
    @Test func earlyLateMissedExtraCounts() {
        let expected = [0.0, 0.375, 0.75, 1.125]
        // tol = 0.08 → early/late beyond 0.04
        let taps = [0.0, 0.375 - 0.06, 0.75 + 0.05, 1.3]
        let g = OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: 1.5, mode: .absolute)
        let f = EchoFeedback(g)
        #expect(f.onTime == 1)
        #expect(f.early == 1)
        #expect(f.late == 1)
        #expect(f.missed == 1)
        #expect(f.extra == 1)
    }

    @Test func listenBlockHasNoResponses() throws {
        let p = Fixtures.pattern("D-MM-02")
        let t = try Timeline.listenBlock(patterns: [p, p], tempo: Tempo(bpm: 80), clickStage: .c)
        #expect(t.responses.isEmpty)
        #expect(t.prompts.map(\.start) == [1.5, 3.0])
        #expect(t.duration == 4.5)
    }
}

@Suite("Attempt errors")
struct AttemptErrorTests {
    let expected = [0.0, 0.375, 0.75, 1.125] // tol 0.08, mean limit 0.04

    func errors(_ taps: [Double], _ mode: TimingMode = .absolute) -> [AttemptError] {
        OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: 1.5, mode: mode).errors
    }

    @Test func passHasNoErrors() {
        #expect(errors(expected).isEmpty)
    }

    @Test func eachKindOfMistake() {
        #expect(errors([0.0, 0.375, 1.125]) == [.missedBeat])
        #expect(errors(expected + [0.56]) == [.extraTap])
        #expect(errors([0.0, 0.375, 1.125, 0.56]) == [.missedBeat, .extraTap])
        #expect(errors(expected.map { $0 + 0.06 }) == [.timingOff])       // all late beyond the mean limit
        #expect(errors([]) == [.missedBeat])
        let drift = expected.map { $0 * 1.12 }                              // tempo drift without a click
        #expect(errors(drift, .relative) == [.timingOff])
    }
}

@Suite("Accuracy scale")
struct AccuracyScoreTests {
    let expected = [0.0, 0.375, 0.75, 1.125] // tol 0.08

    func score(_ taps: [Double]) -> AccuracyScore {
        AccuracyScore(OnsetGrader.grade(expected: expected, taps: taps, responseStart: 0, responseEnd: 1.5, mode: .absolute))
    }

    @Test func meanOfAbsoluteErrors() {
        let s = score([0.01, 0.375 - 0.02, 0.75, 1.125 + 0.03])
        #expect(abs(s.meanError - 0.015) < 1e-9)
        #expect(abs(s.maximum - 0.08) < 1e-9)
        #expect(s.passLimit == 0.5)
        #expect(!s.isMax)
        #expect(abs(s.fraction - 0.015 / 0.08) < 1e-9)
        #expect(score(expected).fraction == 0)
    }

    @Test func missOrExtraIsTheMaximum() {
        #expect(score([0, 0.375, 0.75]).fraction == 1)
        #expect(score(expected + [0.56]).fraction == 1)
    }

    @Test func pulseScore() {
        let beats = (0..<4).map { Double($0) * 0.75 }
        let ok = AccuracyScore(PulseGrader.grade(beats: beats, taps: beats.map { $0 + 0.01 }))
        #expect(abs(ok.meanError - 0.01) < 1e-9 && !ok.isMax && ok.passLimit == nil)
        #expect(AccuracyScore(PulseGrader.grade(beats: beats, taps: Array(beats.dropLast()))).fraction == 1)
    }
}
