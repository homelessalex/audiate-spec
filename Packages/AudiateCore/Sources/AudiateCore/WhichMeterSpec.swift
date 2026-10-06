/// E3: hear a series of patterns in one meter, then name the meter (PS). The count-in gives only the
/// macrobeat, at a tempo shared by the candidate meters, so neither gives the answer away.
public struct WhichMeterSpec: Hashable, Sendable {
    public let unitID: String
    public let level: SkillLevel
    public let series: [Pattern]
    /// Meter ids.
    public let options: [String]
    public let correctIndex: Int
    public let tempo: Tempo

    public init(unitID: String, level: SkillLevel, series: [Pattern], options: [String], correctIndex: Int, tempo: Tempo) {
        self.unitID = unitID
        self.level = level
        self.series = series
        self.options = options
        self.correctIndex = correctIndex
        self.tempo = tempo
    }
}
