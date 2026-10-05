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
    private var latency = 0.0
    private var tapSound = true
    private weak var player: BlockPlayer?

    func run(_ timeline: Timeline, player: BlockPlayer, tapSound: Bool, onFinish: @escaping @MainActor ([Double]) -> Void) throws {
        cancel()
        taps = []
        tapCount = 0
        latency = player.outputLatency
        self.tapSound = tapSound
        self.player = player
        clock = nil
        monitor.start { [weak self] event in self?.tap(event) }
        isRunning = true
        clock = try player.play(timeline) { [weak self] in
            guard let self else { return }
            self.monitor.stop()
            self.isRunning = false
            onFinish(self.taps)
        }
    }

    /// Key or pad press; ignored when no block is running.
    func tap(_ event: TapEvent) {
        guard isRunning, let clock, event.isDown, event.key != .f else { return }
        if tapSound { player?.playTap() }
        taps.append(clock.blockTime(forUptime: event.timestamp) - latency)
        tapCount += 1
    }

    func cancel() {
        monitor.stop()
        if isRunning { isRunning = false }
    }
}
