/// E8: hear a pattern, answer with a different one in the same meter (IA).
public struct AnswerDifferentlySpec: Hashable, Sendable {
    public let unitID: String
    public let prompt: Pattern
    public let tempo: Tempo
    /// Content the answer may use (its grid).
    public let unlocked: Set<ContentKind>

    public init(unitID: String, prompt: Pattern, tempo: Tempo, unlocked: Set<ContentKind>) {
        self.unitID = unitID
        self.prompt = prompt
        self.tempo = tempo
        self.unlocked = unlocked
    }
}
