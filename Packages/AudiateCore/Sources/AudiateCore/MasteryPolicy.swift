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
    public static let teachingEchoes = 3
    /// See-and-hear readings of a new pattern right after its ear echoes.
    public static let teachingReads = 2
    public static let maxNewPatternsPerSessionPerUnit = 2
    public static let evaluationBlockSize = 4...6
    public static let minBlockSize = 3
    /// Rough time per step outside the audio (reading feedback, pressing Return).
    public static let stepOverheadSeconds = 8.0
    /// Rough time per E2 question including its prompt.
    public static let nameSyllablesSeconds = 12.0
}
