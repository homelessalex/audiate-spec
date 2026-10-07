/// Turns MIDI note-ons into taps while an exercise is active (the MIDI counterpart of `KeyTapMonitor`).
@MainActor
public final class MIDITapMonitor {
    private var token: UInt64?

    public init() {}

    /// `twoHands`: split the keyboard into pulse (left) and rhythm (right); otherwise every note is the rhythm.
    public func start(split: MIDISplit = .standard, twoHands: Bool, _ handler: @escaping @MainActor (TapEvent) -> Void) {
        stop()
        token = MIDIInput.shared.addListener { note in
            handler(TapEvent(key: split.role(for: note.note, twoHands: twoHands), isDown: true,
                             timestamp: note.timestamp, source: .midi))
        }
    }

    public func stop() {
        if let token { MIDIInput.shared.removeListener(token) }
        token = nil
    }
}
