public struct SessionPlan: Hashable, Sendable {
    public let steps: [SessionStep]
    /// The levels being learned (new material): one per unit of the current group.
    public let frontiers: [LevelKey]
    public let estimatedSeconds: Double

    public var isEmpty: Bool { steps.isEmpty }
}
