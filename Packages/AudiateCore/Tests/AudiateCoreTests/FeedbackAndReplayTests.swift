import Testing
@testable import AudiateCore

@Suite("Feedback and replay")
struct FeedbackAndReplayTests {
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

    @Test func replayPlaysModelThenYou() throws {
        let p = Fixtures.pattern("D-MM-01") // 24 24 at 80 BPM: 0, 0.75
        let t = try Timeline.replay(pattern: p, tempo: Tempo(bpm: 80), tapsFromDownbeat: [0.02, 0.8])
        let hats = t.sounds.filter { $0.sound == .hiHat }
        #expect(hats.map(\.time) == [1.5, 2.25, 3.02, 3.8])
        #expect(abs(hats[2].duration! - 0.78) < 1e-9)
        #expect(abs(hats[3].duration! - 0.7) < 1e-9)
        #expect(t.duration == 4.5)
    }
}
