/// What a tap is for (docs/04-exercises.md §2). Which keys produce which role is a `KeyMap`.
public enum TapKey: Hashable, Sendable {
    /// The rhythm (one-hand mode, or the right hand in two-hand mode).
    case rhythm
    /// The macrobeats with the left hand in two-hand mode.
    case pulse
    /// Mouse / trackpad click on the tap pad; same role as `rhythm`.
    case pointer
}
