import AVFoundation

/// Maps block-relative seconds ↔ host time, anchored at the block's scheduled start
/// (docs/05-architecture.md §3).
public struct BlockClock: Hashable, Sendable {
    public let anchorHostTime: UInt64

    public init(anchorHostTime: UInt64) {
        self.anchorHostTime = anchorHostTime
    }

    public var anchorSeconds: Double { AVAudioTime.seconds(forHostTime: anchorHostTime) }

    public func blockTime(forHostTime hostTime: UInt64) -> Double {
        AVAudioTime.seconds(forHostTime: hostTime) - anchorSeconds
    }

    /// `NSEvent.timestamp` / `ProcessInfo.systemUptime` are seconds on the same mach clock as host time.
    /// [verify on device] — a constant offset, if any, is absorbed by calibration.
    public func blockTime(forUptime uptime: TimeInterval) -> Double {
        uptime - anchorSeconds
    }

    public func hostTime(forBlockTime seconds: Double) -> UInt64 {
        AVAudioTime.hostTime(forSeconds: anchorSeconds + seconds)
    }
}
