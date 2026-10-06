/// Echo block layout (docs/04-exercises.md §1).
public enum EchoPolicy {
    /// Silent "hold it" measures between prompt and response; the pulse continues.
    /// [uncertain] 1 is a scaffold for beginners; may fade to 0 later.
    public static let gapMeasures = 1
    /// Count-in measures when the meter is new — at the start of a stream in another meter, or on a
    /// change of meter — so the learner can settle into the new metronome. A tempo change alone gets one.
    public static let newMeterCountInMeasures = 2
}
