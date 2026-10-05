/// Calibration plan and acceptance (docs/05-architecture.md §4).
public enum CalibrationPolicy {
    public static let clickCount = 16
    public static let bpm = 90.0
    public static let discardedClicks = 4
    /// Reject if the learner's taps spread more than this (seconds).
    public static let maxIQR = 0.040
    /// Need at least this many matched taps out of the kept clicks.
    public static let minMatchedTaps = 8

    public static var beat: Double { 60 / bpm }
    public static var clickTimes: [Double] { (0..<clickCount).map { Double($0) * beat } }
}
