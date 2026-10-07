import AudiateAudio

/// What a `TapRecorder` listens to and how it turns raw taps into graded times.
struct TapSetup {
    var keyMap: KeyMap = .standard
    var midiSplit: MIDISplit = .standard
    /// MIDI: split the keyboard into left-hand pulse and right-hand rhythm.
    var twoHands = false
    var tapSound = true
    /// Removed from every tap by its source; `.zero` for calibration, which measures them.
    var offsets: InputOffsets = .zero
}
