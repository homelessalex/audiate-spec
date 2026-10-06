/// Metronome scaffolding that fades out by level (docs/02-curriculum.md §6).
public enum ClickStage: String, Codable, CaseIterable, Hashable, Sendable {
    /// Macro + micro beats throughout.
    case a
    /// Macrobeats only throughout.
    case b
    /// Count-in only, then silence.
    case c
    /// Count-in only, then longer silent stretches (pulse drills).
    case d

    var clicksMicrobeats: Bool { self == .a }
    var clicksAfterCountIn: Bool { self == .a || self == .b }

    /// With no click after the count-in the learner's tempo may drift, so grading is relative.
    public var timingMode: TimingMode { clicksAfterCountIn ? .absolute : .relative }

    /// Click scaffold by level and mode (docs/02-curriculum.md §6): teaching A; evaluation of AO B;
    /// evaluation from the notation levels on C (count-in only — the learner keeps the pulse);
    /// free practice B.
    public static func forStep(level: SkillLevel, mode: PracticeMode) -> ClickStage {
        switch mode {
        case .teaching: .a
        case .practice: .b
        case .evaluation: level >= .verbal ? .c : .b
        }
    }
}
