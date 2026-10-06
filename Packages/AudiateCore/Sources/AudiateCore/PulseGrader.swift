/// Grades E10: macrobeats tapped through a silent stretch (docs/04-exercises.md §6).
public enum PulseGrader {
    /// `beats`: the expected macrobeat times in the silence; `taps`: all taps (latency-compensated).
    public static func grade(beats: [Double], taps: [Double]) -> PulseGrade {
        guard let first = beats.first, let last = beats.last, beats.count >= 2 else {
            return PulseGrade(drift: 0, jitter: 0, taps: 0, beats: beats.count, problems: [.lostCount])
        }
        let intervals = zip(beats, beats.dropFirst()).map { $1 - $0 }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let window = (first - intervals[0] / 2)..<(last + intervals[intervals.count - 1] / 2)
        let inside = OnsetGrader.debounce(taps.sorted()).filter { window.contains($0) }

        guard let lastTap = inside.last else {
            return PulseGrade(drift: 0, jitter: 0, taps: 0, beats: beats.count, problems: [.lostCount])
        }
        let drift = (lastTap - last) / mean
        // taps are taken in order as the beats they stand for; ratios compare each interval with its beat
        let n = min(inside.count, beats.count)
        var ratios: [Double] = []
        for i in 0..<max(0, n - 1) {
            let tapInterval = inside[i + 1] - inside[i]
            let beatInterval = beats[i + 1] - beats[i]
            ratios.append(tapInterval / beatInterval)
        }
        let jitter = standardDeviation(ratios)

        var problems: [PulseGrade.Problem] = []
        if inside.count != beats.count { problems.append(.lostCount) }
        if abs(drift) > PulsePolicy.maxDrift { problems.append(.drifted) }
        if jitter > PulsePolicy.maxJitter { problems.append(.uneven) }
        return PulseGrade(drift: drift, jitter: jitter, taps: inside.count, beats: beats.count, problems: problems)
    }

    static func standardDeviation(_ xs: [Double]) -> Double {
        guard xs.count >= 2 else { return 0 }
        let mean = xs.reduce(0, +) / Double(xs.count)
        return (xs.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(xs.count - 1)).squareRoot()
    }
}
