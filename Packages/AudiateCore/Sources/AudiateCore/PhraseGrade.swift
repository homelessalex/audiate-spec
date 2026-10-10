/// E13: every measure of a phrase graded on its own slot with the onset grader; the phrase passes only
/// when every measure does (docs/04-exercises.md "Reading a phrase").
public struct PhraseGrade: Hashable, Sendable {
    public let rhythm: [OnsetGrade]
    /// Two-hand mode: the macrobeat hand, per measure.
    public let pulse: [OnsetGrade]?

    public static func grade(slots: [ResponseSlot], taps: [Double], pulseTaps: [Double]?, mode: TimingMode) -> PhraseGrade {
        let rhythm = slots.map {
            OnsetGrader.grade(expected: $0.expectedOnsets, taps: taps, responseStart: $0.start, responseEnd: $0.end, mode: mode)
        }
        let pulse = pulseTaps.map { taps in
            slots.map { OnsetGrader.grade(expected: $0.macrobeatTimes, taps: taps, responseStart: $0.start, responseEnd: $0.end, mode: mode) }
        }
        return PhraseGrade(rhythm: rhythm, pulse: pulse)
    }

    public func measurePassed(_ i: Int) -> Bool { rhythm[i].passed && (pulse?[i].passed ?? true) }
    public var passed: Bool { !rhythm.isEmpty && rhythm.indices.allSatisfy(measurePassed) }
    /// The worst measure, for rolling statistics.
    public var accuracy: Double {
        rhythm.indices.map { min(rhythm[$0].accuracy, pulse?[$0].accuracy ?? 1) }.min() ?? 0
    }
    /// The first failing measure (0-based).
    public var firstFailing: Int? { rhythm.indices.first { !measurePassed($0) } }
}
