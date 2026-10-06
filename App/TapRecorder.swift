import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Records melodic-rhythm taps (Space, J, the tap pad) in block time with output latency removed.
/// Timing comes from the audio clock anchor and NSEvent timestamps, never from UI timers.
@MainActor
@Observable
final class TapRecorder {
    private(set) var isRunning = false
    private(set) var tapCount = 0
    /// Rhythm taps so far (rhythm keys, pad), in block time with output latency removed (input offset not yet applied).
    private(set) var taps: [Double] = []
    /// Left-hand macrobeat taps (pulse keys) in two-hand mode, same time base.
    private(set) var pulseTaps: [Double] = []
    private let monitor = KeyTapMonitor()
    private var clock: BlockClock?
    private var latency = 0.0
    private var tapSound = true
    private weak var player: BlockPlayer?

    /// Starts listening against `clock` (the audio is already scheduled by the caller).
    func start(clock: BlockClock, player: BlockPlayer, tapSound: Bool, keyMap: KeyMap = .standard) {
        stop()
        taps = []
        pulseTaps = []
        tapCount = 0
        latency = player.outputLatency
        self.tapSound = tapSound
        self.player = player
        self.clock = clock
        isRunning = true
        monitor.start(keyMap: keyMap) { [weak self] event in self?.tap(event) }
    }

    /// Plays a fixed timeline and records until it ends (debug player, calibration).
    func run(_ timeline: Timeline, player: BlockPlayer, tapSound: Bool, keyMap: KeyMap = .standard,
             onFinish: @escaping @MainActor ([Double]) -> Void) throws {
        stop()
        let clock = try player.play(timeline) { [weak self] in
            guard let self else { return }
            self.stop()
            onFinish(self.taps)
        }
        start(clock: clock, player: player, tapSound: tapSound, keyMap: keyMap)
    }

    /// Block time of what is being heard right now (for display only, never for grading).
    func heardTime() -> Double? {
        clock.map { $0.blockTime(forUptime: ProcessInfo.processInfo.systemUptime) - latency }
    }

    /// Key or pad press; ignored when not running.
    func tap(_ event: TapEvent) {
        guard isRunning, let clock, event.isDown else { return }
        if tapSound { player?.playTap() }
        let time = clock.blockTime(forUptime: event.timestamp) - latency
        if event.key == .pulse {
            pulseTaps.append(time)
        } else {
            taps.append(time)
            tapCount += 1
        }
    }

    func stop() {
        monitor.stop()
        isRunning = false
    }

    func cancel() { stop() }
}
