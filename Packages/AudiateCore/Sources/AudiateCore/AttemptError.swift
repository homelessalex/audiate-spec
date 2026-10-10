/// Why a tap attempt failed, told to the learner next to the yes/no (no visual rhythm before SA).
/// Note holds are not graded: the goal is drum parts, where duration is set by the next stroke
/// (docs/04-exercises.md §2, "Grade sustain").
public enum AttemptError: String, CaseIterable, Hashable, Sendable {
    /// An expected note had no tap.
    case missedBeat
    /// A tap where no note starts (e.g. on a rest).
    case extraTap
    /// Every note was hit, but too far off on average or one note beyond the tolerance.
    case timingOff
    /// Without the click the learner's tempo changed (`OnsetGrade.drifted`).
    case tempoDrift
}

extension OnsetGrade {
    /// Empty when the attempt passed.
    public var errors: [AttemptError] {
        guard !passed else { return [] }
        var errors: [AttemptError] = []
        if !misses.isEmpty || hits.isEmpty { errors.append(.missedBeat) }
        if !extras.isEmpty { errors.append(.extraTap) }
        if errors.isEmpty, drifted { errors.append(.tempoDrift) }
        if errors.isEmpty { errors.append(.timingOff) }
        return errors
    }
}
