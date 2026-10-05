/// Tunables of the unfamiliar-pattern generator (docs/03-rhythm-model.md §5).
public struct GeneratorPolicy: Hashable, Sendable {
    /// Chance to tie the last note of one macrobeat into the first of the next, when `tie` is unlocked.
    public var tieProbability = 0.15
    /// Chance to prepend a one-note pickup, when `upbeat` is unlocked.
    public var upbeatProbability = 0.2
    /// Pickup lengths; 6 (a division) is used only when `division` is unlocked.
    public var upbeatTicks = [6, 12]
    /// Cell weight: macro/micro cells 1, cells of newer content 2.
    public var macroMicroWeight = 1.0
    public var newerContentWeight = 2.0
    /// Rejection-sampling budget before giving up.
    public var maxAttempts = 500

    public init() {}

    public static let standard = GeneratorPolicy()

    func weight(of cell: Cell) -> Double {
        cell.minContent == .macroMicro ? macroMicroWeight : newerContentWeight
    }
}
