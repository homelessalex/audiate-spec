import Testing
@testable import AudiateCore

@Suite("CalibrationAnalyzer")
struct CalibrationAnalyzerTests {
    let clicks = CalibrationPolicy.clickTimes

    @Test func planIs16ClicksAt90BPM() {
        #expect(clicks.count == 16)
        #expect(abs(clicks[1] - 60.0 / 90.0) < 1e-12)
    }

    @Test func steadyTapperGivesMedianOffset() {
        let jitter = [0.004, -0.003, 0.002, -0.001, 0.0, 0.003, -0.002, 0.001, -0.004, 0.002, 0.0, -0.001]
        // first 4 taps are wild and must be discarded
        let taps = [0.3, -0.2, 0.25, 0.1] .enumerated().map { clicks[$0.offset] + $0.element }
            + clicks.dropFirst(4).enumerated().map { $0.element + 0.030 + jitter[$0.offset] }
        let r = CalibrationAnalyzer.analyze(clickTimes: clicks, taps: taps)
        #expect(r.isAccepted)
        #expect(abs((r.medianOffset ?? 0) - 0.030) < 0.0015)
        #expect(r.offsets.count == 12)
    }

    @Test func inconsistentTapperIsRejected() {
        let spread = [0.0, 0.06, -0.05, 0.07, -0.06, 0.05, 0.0, -0.07, 0.06, -0.05, 0.04, -0.04]
        let taps = clicks.dropFirst(4).enumerated().map { $0.element + spread[$0.offset] }
        let r = CalibrationAnalyzer.analyze(clickTimes: clicks, taps: taps)
        #expect(!r.isAccepted)
        #expect((r.iqr ?? 0) > CalibrationPolicy.maxIQR)
    }

    @Test func tooFewTapsIsRejected() {
        let r = CalibrationAnalyzer.analyze(clickTimes: clicks, taps: Array(clicks.suffix(5)))
        #expect(!r.isAccepted)
    }

    @Test func latencyCompensation() {
        let c = LatencyCompensation(outputLatency: 0.012, inputOffset: 0.030)
        #expect(abs(c.blockTime(forRawBlockTime: 1.0) - 0.958) < 1e-12)
    }
}
