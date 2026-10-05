public enum TimingMode: String, Codable, Hashable, Sendable {
    /// Click present: taps are compared with the expected times directly.
    case absolute
    /// Click absent: a constant offset and a tempo change within limits are factored out.
    case relative
}
