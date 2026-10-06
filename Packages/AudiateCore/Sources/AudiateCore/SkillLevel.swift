/// Skill Learning Sequence levels, in order (docs/01-methodology.md §4, docs/02-curriculum.md §2).
/// The theory track (TU) is separate; see `Gate.isTheoryUnlocked`.
public enum SkillLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case aural = "AO"
    /// Gordon's verbal association (syllables). Here: notation association — the pattern's notation is
    /// attached to the sound once the unit has passed AO (deviation, docs/01-methodology.md §7).
    case verbal = "VA"
    case partialSynthesis = "PS"
    case symbolic = "SA"
    case compositeSynthesis = "CS"
    case generalizationAural = "GA"
    case generalizationVerbal = "GV"
    case generalizationSymbolic = "GS"
    case improvisationAural = "IA"
    case improvisationSymbolic = "IS"

    public var code: String { rawValue }

    public static func < (lhs: SkillLevel, rhs: SkillLevel) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }

    /// Inference levels use generated (unfamiliar) patterns and are tracked per unit, not per pattern.
    public var isInference: Bool { self >= .generalizationAural }

    /// Levels that use notation.
    public var isSymbolic: Bool {
        [.symbolic, .compositeSynthesis, .generalizationSymbolic, .improvisationSymbolic].contains(self)
    }

    /// Where a learner who keeps failing this level goes back to (bridging, docs/02-curriculum.md §4).
    /// nil for the purely aural familiar levels, which have nothing to bridge to.
    public var bridgeLevel: SkillLevel? {
        switch self {
        case .aural, .verbal, .partialSynthesis: nil
        case .symbolic, .compositeSynthesis, .generalizationVerbal: .verbal
        case .generalizationAural: .aural
        case .generalizationSymbolic: .generalizationVerbal
        case .improvisationAural: .generalizationAural
        case .improvisationSymbolic: .improvisationAural
        }
    }
}
