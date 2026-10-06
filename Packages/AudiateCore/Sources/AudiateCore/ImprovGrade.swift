public struct ImprovGrade: Hashable, Sendable {
    public enum Problem: String, Hashable, Sendable {
        /// A tap too far from any grid point of the unlocked content.
        case offGrid
        /// Fewer than two onsets in the measure.
        case tooFew
        /// The same onsets as the prompt: an echo, not an answer.
        case sameAsPrompt
        /// The pulse wasn't held (relative tempo off by more than allowed).
        case tempoDrift
    }

    /// Onset ticks of the answer, snapped to the grid.
    public let quantizedOnsets: [Int]
    public let tempoRatio: Double
    public let problems: [Problem]

    public var passed: Bool { problems.isEmpty }
}
