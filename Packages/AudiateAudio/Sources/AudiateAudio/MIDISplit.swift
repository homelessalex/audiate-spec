/// Which MIDI notes tap the pulse and which tap the rhythm. Set by the learner in Settings.
public struct MIDISplit: Codable, Hashable, Sendable {
    /// Lowest note of the right-hand (rhythm) range; in two-hand mode notes below it keep the pulse.
    public var lowestRhythmNote: UInt8

    public init(lowestRhythmNote: UInt8) {
        self.lowestRhythmNote = lowestRhythmNote
    }

    /// Middle C: left hand below it, right hand from it up.
    public static let standard = MIDISplit(lowestRhythmNote: 60)

    /// With one hand every note is the rhythm (any key or pad works); with two the keyboard is split.
    public func role(for note: UInt8, twoHands: Bool) -> TapKey {
        twoHands && note < lowestRhythmNote ? .pulse : .rhythm
    }
}
