/// E1: an uninterrupted block of echoes in one meter.
public struct EchoBlockSpec: Hashable, Sendable {
    public let items: [PlannedItem]
    public let meterID: String
    public let tempo: Tempo
    public let clickStage: ClickStage
    public let mode: PracticeMode
    /// The pattern's notation is shown during the echo (VA: notation association).
    public let showNotation: Bool
    /// Silent measures between prompt and response (the audiation drill uses more than the default).
    public let gapMeasures: Int

    /// E11 "audiate the gap": a longer silent gap than the usual hold measure.
    public var isAudiationDrill: Bool { gapMeasures > EchoPolicy.gapMeasures }

    /// The exercise its attempts are recorded as.
    public var exercise: ExerciseKind { isAudiationDrill ? .audiateTheGap : .echo }

    public init(items: [PlannedItem], meterID: String, tempo: Tempo, clickStage: ClickStage, mode: PracticeMode,
                showNotation: Bool, gapMeasures: Int = EchoPolicy.gapMeasures) {
        self.items = items
        self.meterID = meterID
        self.tempo = tempo
        self.clickStage = clickStage
        self.mode = mode
        self.showNotation = showNotation
        self.gapMeasures = gapMeasures
    }
}
