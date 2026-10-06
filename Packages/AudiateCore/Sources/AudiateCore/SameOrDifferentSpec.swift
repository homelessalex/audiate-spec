/// E4: two patterns in one meter, one after the other — same or different? (GA)
public struct SameOrDifferentSpec: Hashable, Sendable {
    public let unitID: String
    public let first: Pattern
    public let second: Pattern
    public let tempo: Tempo

    public init(unitID: String, first: Pattern, second: Pattern, tempo: Tempo) {
        self.unitID = unitID
        self.first = first
        self.second = second
        self.tempo = tempo
    }

    public var isSame: Bool { first.shape == second.shape }
}
