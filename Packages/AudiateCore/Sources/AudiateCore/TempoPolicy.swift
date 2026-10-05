import Foundation

/// Default tempos and ranges (docs/02-curriculum.md §7).
/// [uncertain] Pragmatic defaults, not from Gordon.
public enum TempoPolicy {
    public static let dupleBPM = 80.0
    public static let dupleRange = 66.0...96.0
    public static let tripleBPM = 56.0
    public static let tripleRange = 46.0...66.0
    public static let unusualEighthBPM = 200.0
    public static let unusualEighthRange = 168.0...232.0

    /// Teaching mode starts this much slower than the standard tempo (docs/01-methodology.md §5).
    public static let teachingFactor = 0.85
    /// Each failed teaching attempt slows the next one by this factor.
    public static let retryFactor = 0.95

    /// The meter's tempo range; its lower bound is the slowest tempo at which the macrobeat still
    /// feels like the pulse.
    public static func range(for meter: Meter) -> ClosedRange<Double> {
        meter.isUnusual ? unusualEighthRange : (meter.macrobeats.first == 3 ? tripleRange : dupleRange)
    }

    /// Tempo of teaching attempt `attempt` (1-based): slower than standard, a bit slower after each
    /// miss, never below the meter's range. Evaluation always uses `Tempo.standard(for:)`.
    public static func teaching(for meter: Meter, attempt: Int = 1) -> Tempo {
        let bpm = Tempo.standard(for: meter).bpm * teachingFactor * pow(retryFactor, Double(max(0, attempt - 1)))
        return Tempo(bpm: max(bpm, range(for: meter).lowerBound))
    }
}
