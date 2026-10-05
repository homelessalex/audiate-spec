/// Keys used for tapping (docs/04-exercises.md §2).
public enum TapKey: Hashable, Sendable {
    /// Melodic rhythm in one-hand mode.
    case space
    /// Macrobeats in two-hand mode.
    case f
    /// Melodic rhythm in two-hand mode.
    case j

    init?(keyCode: UInt16) {
        switch keyCode {
        case 49: self = .space
        case 3: self = .f
        case 38: self = .j
        default: return nil
        }
    }
}
