public struct TimeSignature: Codable, Hashable, Sendable, CustomStringConvertible {
    public let beats: Int
    public let beatUnit: Int

    public init(beats: Int, beatUnit: Int) {
        self.beats = beats
        self.beatUnit = beatUnit
    }

    /// Parses "6/8".
    public init(_ string: String) throws {
        let parts = string.split(separator: "/")
        guard parts.count == 2, let beats = Int(parts[0]), let unit = Int(parts[1]), beats > 0, unit > 0 else {
            throw RhythmError.invalidTimeSignature(string)
        }
        self.init(beats: beats, beatUnit: unit)
    }

    public var description: String { "\(beats)/\(beatUnit)" }
}
