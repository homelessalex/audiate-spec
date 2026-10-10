/// Where the learner stands on the phrase ladder (`PhrasePolicy.rungs`), derived from the graded E13
/// attempts: each records its rung in `patternID`, so a step planned at an older rung can't move the ladder.
public enum PhraseLadder {
    public static func rung(after attempts: [Attempt]) -> Int {
        var rung = 0, passes = 0, fails = 0
        for a in attempts where a.exercise == .readPhrase && a.mode == .evaluation {
            guard let r = a.patternID.flatMap(rungIndex), r == rung else { continue }
            if a.passed {
                passes += 1
                fails = 0
                if passes >= PhrasePolicy.passesToAdvance, rung + 1 < PhrasePolicy.rungs.count { (rung, passes) = (rung + 1, 0) }
            } else {
                fails += 1
                passes = 0
                if fails >= PhrasePolicy.failsToStepBack, rung > 0 { (rung, fails) = (rung - 1, 0) }
            }
        }
        return rung
    }

    /// The `patternID` an E13 attempt is recorded with.
    public static func patternID(rung: Int) -> String { "phrase-r\(rung)" }

    static func rungIndex(_ patternID: String) -> Int? {
        guard patternID.hasPrefix("phrase-r") else { return nil }
        return Int(patternID.dropFirst("phrase-r".count))
    }
}
