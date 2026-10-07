/// The learner's calibrated input offset per source, seconds (`inputOffset` in docs/05-architecture.md §4).
public struct InputOffsets: Hashable, Sendable {
    public var computer: Double
    public var midi: Double

    public init(computer: Double, midi: Double) {
        self.computer = computer
        self.midi = midi
    }

    public static let zero = InputOffsets(computer: 0, midi: 0)

    public subscript(source: InputSource) -> Double {
        switch source {
        case .computer: computer
        case .midi: midi
        }
    }
}
