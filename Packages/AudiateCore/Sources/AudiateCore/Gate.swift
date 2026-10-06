/// What unlocks what (docs/02-curriculum.md §3). Passed levels are never re-locked.
public enum Gate {
    public static func isUnlocked(_ key: LevelKey, curriculum: Curriculum, passed: Set<LevelKey>) -> Bool {
        if passed.contains(key) { return true }
        guard curriculum.unit(id: key.unitID) != nil else { return false }
        func has(_ level: SkillLevel) -> Bool { passed.contains(LevelKey(unitID: key.unitID, level: level)) }

        switch key.level {
        case .aural:
            // a group opens when every unit of the previous group has passed VA
            return curriculum.previousGroup(of: key.unitID).allSatisfy { passed.contains(LevelKey(unitID: $0.id, level: .verbal)) }
        case .verbal:
            return has(.aural)
        case .partialSynthesis:
            // PS needs a contrast: at least two different meters with VA passed.
            let meters = curriculum.units
                .filter { passed.contains(LevelKey(unitID: $0.id, level: .verbal)) }
                .flatMap(\.meters)
            return has(.verbal) && Set(meters).count >= 2
        case .symbolic:
            // Reading unfamiliar notation of the unit's (familiar) patterns, right after notation association.
            return has(.verbal)
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

    /// Sound before sight: a unit's notation appears only once the unit has passed AO by ear.
    public static func canShowNotation(unitID: String, passed: Set<LevelKey>) -> Bool {
        passed.contains(LevelKey(unitID: unitID, level: .aural))
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
