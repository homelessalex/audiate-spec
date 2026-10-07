/// A sound the audio layer can play; it maps each case to a sample. No voice: prompts are percussion
/// and syllables are shown as text (docs/01-methodology.md §7).
public enum Sound: Hashable, Sendable {
    /// Prompt note: open hi-hat, choked when the note ends so durations are audible.
    case hiHat
    /// Metronome / count-in: strong on macrobeats, weak on microbeats.
    case click(accented: Bool)
    /// Metronome / count-in on the measure's first beat: lower than the macrobeat click.
    case downbeat

    /// The click for a beat: `downbeat` on the measure's first macrobeat, then strong / weak.
    public static func click(tick: Int, micro: Int) -> Sound {
        tick == 0 ? .downbeat : .click(accented: micro == 0)
    }

    /// Any metronome sound on a macrobeat (the downbeat included).
    public var isMacrobeatClick: Bool { self == .downbeat || self == .click(accented: true) }
}
