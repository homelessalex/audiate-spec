/// Default tempos and ranges (docs/02-curriculum.md §7).
/// [uncertain] Pragmatic defaults, not from Gordon.
public enum TempoPolicy {
    public static let dupleBPM = 80.0
    public static let dupleRange = 66.0...96.0
    public static let tripleBPM = 56.0
    public static let tripleRange = 46.0...66.0
    public static let unusualEighthBPM = 200.0
    public static let unusualEighthRange = 168.0...232.0

    /// Teaching mode plays this much slower than the standard tempo (docs/01-methodology.md §5).
    /// Constant within a step: the session is one uninterrupted pulse.
    public static let teachingFactor = 0.85

    /// The meter's tempo range; its lower bound is the slowest tempo at which the macrobeat still
    /// feels like the pulse.
    public static func range(for meter: Meter) -> ClosedRange<Double> {
        meter.isUnusual ? unusualEighthRange : (meter.macrobeats.first == 3 ? tripleRange : dupleRange)
    }

    /// Teaching tempo: slower than standard, never below the meter's range.
    /// Evaluation always uses `Tempo.standard(for:)`.
    public static func teaching(for meter: Meter) -> Tempo {
        Tempo(bpm: max(Tempo.standard(for: meter).bpm * teachingFactor, range(for: meter).lowerBound))
    }
}
