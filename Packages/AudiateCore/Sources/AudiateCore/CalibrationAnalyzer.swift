/// `inputOffset = median(tap − click)` over clicks after the first few; rejected if too inconsistent.
public enum CalibrationAnalyzer {
    /// `taps` must already have the output latency removed (but not the input offset).
    public static func analyze(clickTimes: [Double], taps: [Double]) -> CalibrationResult {
        let halfBeat = CalibrationPolicy.beat / 2
        let offsets = clickTimes.dropFirst(CalibrationPolicy.discardedClicks).compactMap { click -> Double? in
            guard let nearest = taps.min(by: { abs($0 - click) < abs($1 - click) }),
                  abs(nearest - click) < halfBeat else { return nil }
            return nearest - click
        }
        let sorted = offsets.sorted()
        let median = quantile(sorted, 0.5)
        let iqr = quantile(sorted, 0.75).flatMap { q3 in quantile(sorted, 0.25).map { q3 - $0 } }
        let accepted = offsets.count >= CalibrationPolicy.minMatchedTaps && (iqr ?? .infinity) <= CalibrationPolicy.maxIQR
        return CalibrationResult(offsets: offsets, medianOffset: median, iqr: iqr, isAccepted: accepted)
    }

    /// Linear-interpolated quantile of sorted values.
    static func quantile(_ sorted: [Double], _ q: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = Int(pos.rounded(.up))
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - Double(lo))
    }
}
