/// Echo block layout (docs/04-exercises.md §1).
public enum EchoPolicy {
    /// Silent "hold it" measures between prompt and response; the pulse continues.
    /// [uncertain] 1 is a scaffold for beginners; may fade to 0 later.
    public static let gapMeasures = 1
}
