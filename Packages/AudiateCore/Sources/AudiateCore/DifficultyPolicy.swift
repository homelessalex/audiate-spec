/// Weights and thresholds of the difficulty heuristic (docs/03-rhythm-model.md §6).
/// [uncertain] This is a heuristic, not Gordon's empirical classification.
public enum DifficultyPolicy {
    static let onsetWeight = 0.4
    static let offMicrobeatWeight = 0.5
    static let syncopationWeight = 1.5
    static let contentWeight: [ContentKind: Double] = [
        .macroMicro: 0, .division: 1, .elongation: 1.5, .rest: 1.5, .tie: 2, .upbeat: 2,
        // Not in build_patterns.py (library combined patterns are tagged macro_micro); used for generated ones.
        .combined: 1,
    ]
    static let moderateFrom = 2.5
    static let difficultFrom = 4.5
}
