/// Two-hand mode (docs/04-exercises.md §2): one hand keeps the macrobeats (F), the other plays the
/// rhythm (J / Space / pad). Each is graded with the onset grader; the attempt passes only if both do.
public struct TwoHandGrade: Hashable, Sendable {
    public let rhythm: OnsetGrade
    /// Macrobeats of the response measure.
    public let pulse: OnsetGrade

    public init(rhythm: OnsetGrade, pulse: OnsetGrade) {
        self.rhythm = rhythm
        self.pulse = pulse
    }

    public static func grade(slot: ResponseSlot, rhythmTaps: [Double], pulseTaps: [Double], mode: TimingMode) -> TwoHandGrade {
        TwoHandGrade(
            rhythm: OnsetGrader.grade(expected: slot.expectedOnsets, taps: rhythmTaps, responseStart: slot.start,
                                      responseEnd: slot.end, mode: mode),
            pulse: OnsetGrader.grade(expected: slot.macrobeatTimes, taps: pulseTaps, responseStart: slot.start,
                                     responseEnd: slot.end, mode: mode)
        )
    }

    public var passed: Bool { rhythm.passed && pulse.passed }
    public var accuracy: Double { min(rhythm.accuracy, pulse.accuracy) }
}
