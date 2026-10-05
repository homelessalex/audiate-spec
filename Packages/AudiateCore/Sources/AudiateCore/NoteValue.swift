public enum NoteValue: String, Codable, Hashable, Sendable {
    case half
    case quarter
    case eighth
    case sixteenth = "16th"

    /// Beams (or flags) this value carries; 0 for quarter and longer.
    public var beamCount: Int {
        switch self {
        case .half, .quarter: 0
        case .eighth: 1
        case .sixteenth: 2
        }
    }
}
