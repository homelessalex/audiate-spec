public enum EventKind: String, Codable, Hashable, Sendable {
    case note
    case rest
    /// Tied-into note: sounding, but no new onset.
    case continuation
}
