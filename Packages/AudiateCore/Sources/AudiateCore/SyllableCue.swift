/// One syllable of a prompt, timed for synchronized display (VA teaching mode).
public struct SyllableCue: Hashable, Sendable {
    /// Seconds from block start.
    public let time: Double
    public let duration: Double
    /// Display form: `Du`, `(de)` for rests, `[Du]` for tied-into notes.
    public let text: String
    public let kind: EventKind
}
