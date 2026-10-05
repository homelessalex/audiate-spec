public struct NotationValue: Codable, Hashable, Sendable {
    public let value: NoteValue
    public let dots: Int
    /// 3 for a triplet member, nil otherwise.
    public let tuplet: Int?

    public init(value: NoteValue, dots: Int, tuplet: Int?) {
        self.value = value
        self.dots = dots
        self.tuplet = tuplet
    }
}
