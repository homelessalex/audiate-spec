/// A sound the audio layer can play; it maps each case to a sample. No voice: prompts are percussion
/// and syllables are shown as text (docs/01-methodology.md §7).
public enum Sound: Hashable, Sendable {
    /// Prompt note: open hi-hat, choked when the note ends so durations are audible.
    case hiHat
    /// Metronome / count-in: strong on macrobeats, weak on microbeats.
    case click(accented: Bool)
}
