public enum TimelineError: Error, Hashable, Sendable {
    case emptyBlock
    case mixedMeters
    /// A phrase (E13) joins measures; a pickup would overlap the measure before it.
    case pickupInPhrase
}
