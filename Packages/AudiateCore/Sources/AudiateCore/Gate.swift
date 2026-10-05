/// What unlocks what (docs/02-curriculum.md §3). Passed levels are never re-locked.
public enum Gate {
    public static func isUnlocked(_ key: LevelKey, curriculum: Curriculum, passed: Set<LevelKey>) -> Bool {
        if passed.contains(key) { return true }
        guard let index = curriculum.index(of: key.unitID) else { return false }
        func has(_ level: SkillLevel) -> Bool { passed.contains(LevelKey(unitID: key.unitID, level: level)) }

        switch key.level {
        case .aural:
            guard index > 0 else { return true }
            return passed.contains(LevelKey(unitID: curriculum.units[index - 1].id, level: .verbal))
        case .verbal:
            return has(.aural)
        case .partialSynthesis:
            // PS needs a contrast: at least two different meters with VA passed.
            let meters = curriculum.units
                .filter { passed.contains(LevelKey(unitID: $0.id, level: .verbal)) }
                .flatMap(\.meters)
            return has(.verbal) && Set(meters).count >= 2
        case .symbolic:
            // Sound before sight: no notation of a unit's patterns before this.
            return has(.partialSynthesis)
        case .compositeSynthesis:
            return has(.symbolic)
        case .generalizationAural, .generalizationVerbal:
            return has(.verbal) && has(.symbolic)
        case .generalizationSymbolic:
            return has(.compositeSynthesis) && has(.generalizationVerbal)
        case .improvisationAural:
            return has(.generalizationVerbal)
        case .improvisationSymbolic:
            return has(.generalizationSymbolic) && has(.improvisationAural)
        }
    }

    public static func status(of key: LevelKey, curriculum: Curriculum, passed: Set<LevelKey>,
                              started: Set<LevelKey>) -> LevelStatus {
        if passed.contains(key) { return .passed }
        guard isUnlocked(key, curriculum: curriculum, passed: passed) else { return .locked }
        return started.contains(key) ? .inProgress : .available
    }

    /// The theory track opens when U4 reaches CS.
    public static func isTheoryUnlocked(passed: Set<LevelKey>) -> Bool {
        passed.contains(LevelKey(unitID: "U4", level: .compositeSynthesis))
    }
}
