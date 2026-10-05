import AudiateAudio
import AudiateCore
import Observation

/// Plays a timeline and records melodic-rhythm taps in block time, output latency removed.
/// Timing comes from the audio clock anchor and NSEvent timestamps, never from UI timers.
@MainActor
@Observable
final class TapRecorder {
    private(set) var isRunning = false
    private(set) var tapCount = 0
    private let monitor = KeyTapMonitor()
    private var taps: [Double] = []
    private var clock: BlockClock?

    func run(_ timeline: Timeline, player: BlockPlayer, tapSound: Bool, onFinish: @escaping @MainActor ([Double]) -> Void) throws {
        cancel()
        taps = []
        tapCount = 0
        let latency = player.outputLatency
        clock = nil
        monitor.start { [weak self] event in
            guard let self, let clock = self.clock, event.isDown, event.key != .f else { return }
            if tapSound { player.playTap() }
            self.taps.append(clock.blockTime(forUptime: event.timestamp) - latency)
            self.tapCount += 1
        }
        isRunning = true
        clock = try player.play(timeline) { [weak self] in
            guard let self else { return }
            self.monitor.stop()
            self.isRunning = false
            onFinish(self.taps)
        }
    }

    func cancel() {
        monitor.stop()
        if isRunning { isRunning = false }
    }
}
