/// Exercise catalog ids (docs/04-exercises.md §1).
public enum ExerciseKind: String, Codable, CaseIterable, Hashable, Sendable {
    case echo = "E1"
    /// Gordon's "name the syllables", here: pick the notation (VA = notation association).
    case nameNotation = "E2"
    case whichMeter = "E3"
    case sameOrDifferent = "E4"
    case read = "E5"
    case write = "E6"
    case meterFromNotation = "E7"
    case answerDifferently = "E8"
    case composeAndPerform = "E9"
    case holdThePulse = "E10"
    case audiateTheGap = "E11"
    case theory = "E12"
}
