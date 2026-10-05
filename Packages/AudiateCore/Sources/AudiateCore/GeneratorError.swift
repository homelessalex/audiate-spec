public enum GeneratorError: Error, Hashable, Sendable {
    /// No cell of this macrobeat size is unlocked.
    case noCells(macrobeatSize: Int)
    /// Every combination tried was familiar or invalid (e.g. only macro/micro unlocked in duple).
    case noUnfamiliarPattern(meterID: String)
}
