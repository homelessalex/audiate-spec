/// What a measure of a block is for; drives the on-screen phase label.
public enum MeasureRole: Hashable, Sendable {
    case countIn
    /// The pattern sounds (echo) or, without prompt sound, the learner looks ahead at its notation (reading).
    case prompt(Int)
    /// Silent measure to audiate the pattern before answering.
    case hold(Int)
    case response(Int)
}
