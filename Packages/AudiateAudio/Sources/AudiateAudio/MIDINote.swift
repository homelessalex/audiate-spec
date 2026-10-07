/// A MIDI note-on (velocity > 0) with its host-clock time in seconds.
public struct MIDINote: Hashable, Sendable {
    public let note: UInt8
    public let velocity: UInt8
    /// Seconds on the host-time clock, the same clock as `BlockClock` and `NSEvent.timestamp`.
    public let timestamp: Double

    public init(note: UInt8, velocity: UInt8, timestamp: Double) {
        self.note = note
        self.velocity = velocity
        self.timestamp = timestamp
    }

    /// "C4" for 60 (middle C).
    public static func name(_ note: UInt8) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        return names[Int(note) % 12] + String(Int(note) / 12 - 1)
    }
}
