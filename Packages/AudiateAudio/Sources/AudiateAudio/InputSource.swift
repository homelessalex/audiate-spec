/// Where a tap came from. Each source has its own latency, so each is calibrated on its own.
public enum InputSource: String, Codable, Hashable, Sendable, CaseIterable {
    /// Computer keyboard and the trackpad / mouse tap pad.
    case computer
    /// A MIDI keyboard or pad controller (docs/05-architecture.md §4).
    case midi
}
