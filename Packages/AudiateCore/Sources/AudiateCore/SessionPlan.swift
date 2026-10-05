public struct SessionPlan: Hashable, Sendable {
    public let steps: [SessionStep]
    /// The level being learned (new material), if any.
    public let frontier: LevelKey?
    public let estimatedSeconds: Double

    public var isEmpty: Bool { steps.isEmpty }
}
