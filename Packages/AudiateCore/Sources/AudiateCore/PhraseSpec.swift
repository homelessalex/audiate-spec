/// E13: phrases of familiar patterns, one per measure, read without a break (docs/04-exercises.md).
public struct PhraseSpec: Hashable, Sendable {
    /// Each phrase: its patterns, one per measure, all in `meterID`, none with a pickup.
    public let phrases: [[Pattern]]
    /// Index into `PhrasePolicy.rungs`.
    public let rung: Int
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode

    public init(phrases: [[Pattern]], rung: Int, meterID: String, tempo: Tempo,
                clickStage: ClickStage = PhrasePolicy.clickStage, mode: PracticeMode = .evaluation) {
        self.phrases = phrases
        self.rung = rung
        self.meterID = meterID
        self.tempo = tempo
        self.clickStage = clickStage
        self.mode = mode
    }

    /// `measures` patterns from `pool` (one meter) in random order; the same pattern never twice in a row
    /// when the pool has two or more. Nil for an empty pool.
    public static func phrase(from pool: [Pattern], measures: Int, using rng: inout some RandomNumberGenerator) -> [Pattern]? {
        guard !pool.isEmpty else { return nil }
        var phrase: [Pattern] = []
        for _ in 0..<measures {
            let choices = pool.count > 1 ? pool.filter { $0.id != phrase.last?.id } : pool
            phrase.append(choices.randomElement(using: &rng)!)
        }
        return phrase
    }
}
