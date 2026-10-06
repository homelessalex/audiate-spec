/// E7: a series of notated patterns with the time signature hidden; name the meter (CS). Silent.
public struct MeterFromNotationSpec: Hashable, Sendable {
    public let unitID: String
    public let series: [Pattern]
    /// Meter ids.
    public let options: [String]
    public let correctIndex: Int

    public init(unitID: String, series: [Pattern], options: [String], correctIndex: Int) {
        self.unitID = unitID
        self.series = series
        self.options = options
        self.correctIndex = correctIndex
    }
}
