/// Every mastery, review and session threshold in one place (docs/02-curriculum.md §4–5).
/// [uncertain] Pragmatic values, not from Gordon; tune here.
public enum MasteryPolicy {
    // Familiar-pattern levels
    public static let passesPerPattern = 2
    public static let distinctDaysPerPattern = 2
    public static let rollingWindow = 12
    public static let rollingAccuracy = 0.85

    // Inference levels
    public static let inferenceAttempts = 15
    public static let inferenceDistinctDays = 2
    public static let inferenceRollingAccuracy = 0.80

    // Review (Leitner)
    public static let reviewIntervalsDays = [1, 2, 4, 8, 16, 32]
    public static let failsBeforeBridge = 2

    // Session
    public static let sessionSeconds = 12.0 * 60
    public static let reviewShare = 0.40
    /// Teaching mode repeats a pattern until it is performed correctly, at most this many times;
    /// after that the pattern counts as introduced anyway and comes back in evaluation.
    public static let maxTeachingAttempts = 4
    /// Rough time the yes/no verdict stays on screen after each attempt.
    public static let verdictSeconds = 1.2
    /// Per calendar day (sessions chain into one flow, so the day is the unit).
    public static let maxNewPatternsPerDayPerUnit = 2
    /// Evaluations of one pattern per exercise per day; more adds little before the next day,
    /// and mastery needs passes on two different days anyway.
    public static let maxEvaluationsPerPatternPerDay = 4
    public static let evaluationBlockSize = 4...6
    public static let minBlockSize = 3
    /// Rough time per step outside the audio (reading feedback, pressing Return).
    public static let stepOverheadSeconds = 8.0
    /// Rough time per E2 question including its prompt and the choice.
    public static let nameNotationSeconds = 12.0
}
