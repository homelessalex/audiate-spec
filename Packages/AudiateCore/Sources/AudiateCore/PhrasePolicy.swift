/// Phrase reading (E13, docs/04-exercises.md "Reading a phrase"): the ladder and the amounts.
/// [uncertain] Pragmatic values, not from Gordon; tune here.
public enum PhrasePolicy {
    /// One step of the ladder: phrase length and tempo as a fraction of the standard tempo.
    public struct Rung: Hashable, Sendable {
        public let measures: Int
        public let tempoFactor: Double
    }

    /// Short and a little slower first; longer phrases restart a little below the standard tempo.
    /// Never below the meter's range (`tempo(for:meter:)`): slower, the macrobeat stops feeling like the pulse.
    public static let rungs: [Rung] = [
        Rung(measures: 2, tempoFactor: 0.85), Rung(measures: 2, tempoFactor: 0.92), Rung(measures: 2, tempoFactor: 1.0),
        Rung(measures: 3, tempoFactor: 0.92), Rung(measures: 3, tempoFactor: 1.0),
        Rung(measures: 4, tempoFactor: 0.92), Rung(measures: 4, tempoFactor: 1.0),
    ]

    /// The rung's tempo in `meter`: a fraction of the standard tempo, never below the meter's range.
    public static func tempo(for rung: Rung, meter: Meter) -> Tempo {
        Tempo(bpm: max((Tempo.standard(for: meter).bpm * rung.tempoFactor).rounded(), TempoPolicy.range(for: meter).lowerBound))
    }
    /// Graded phrases passed in a row at a rung to climb to the next.
    public static let passesToAdvance = 3
    /// Graded phrases failed in a row at a rung to step one back.
    public static let failsToStepBack = 2
    public static let phrasesPerStep = 4
    public static let maxPhrasesPerDay = 12
    /// Macrobeats throughout: the task is reading, not holding the pulse.
    public static let clickStage = ClickStage.b
    /// Measures the review stays on screen after the phrase while the pulse goes on, the last of them
    /// being the next attempt's lead-in (no "get ready" of its own: the look measures follow); a miss
    /// longer, to see which measure went wrong.
    public static let passedReviewMeasures = 1
    public static let missedReviewMeasures = 3
    /// Stands for the track where an attempt needs a unit (it is no curriculum unit: no mastery, no review).
    public static let unitID = "phrase"
}
