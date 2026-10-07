import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Records taps (tap keys, the tap pad, a MIDI keyboard) in block time with output latency and the
/// calibrated input offset of each tap's source removed. Timing comes from the audio clock anchor and
/// NSEvent / CoreMIDI host timestamps, never from UI timers.
@MainActor
@Observable
final class TapRecorder {
    private(set) var isRunning = false
    private(set) var tapCount = 0
    /// Rhythm taps so far (rhythm keys, pad, MIDI right hand), in compensated block time.
    private(set) var taps: [Double] = []
    /// Where each of `taps` came from (calibration measures one source at a time).
    private(set) var tapSources: [InputSource] = []
    /// Left-hand macrobeat taps (pulse keys, MIDI left hand) in two-hand mode, same time base.
    private(set) var pulseTaps: [Double] = []
    private let keys = KeyTapMonitor()
    private let midi = MIDITapMonitor()
    private var clock: BlockClock?
    private var latency = 0.0
    private var setup = TapSetup()
    /// Last accepted tap per hand, for the debounce.
    private var lastTap: [Bool: Double] = [:]
    private weak var player: BlockPlayer?

    /// Starts listening against `clock` (the audio is already scheduled by the caller).
    func start(clock: BlockClock, player: BlockPlayer, setup: TapSetup) {
        stop()
        taps = []
        tapSources = []
        pulseTaps = []
        lastTap = [:]
        tapCount = 0
        latency = player.outputLatency
        self.setup = setup
        self.player = player
        self.clock = clock
        isRunning = true
        keys.start(keyMap: setup.keyMap) { [weak self] event in self?.tap(event) }
        midi.start(split: setup.midiSplit, twoHands: setup.twoHands) { [weak self] event in self?.tap(event) }
    }

    /// Plays a fixed timeline and records until it ends (debug player, calibration).
    func run(_ timeline: Timeline, player: BlockPlayer, setup: TapSetup,
             onFinish: @escaping @MainActor ([Double]) -> Void) throws {
        stop()
        let clock = try player.play(timeline) { [weak self] in
            guard let self else { return }
            self.stop()
            onFinish(self.taps)
        }
        start(clock: clock, player: player, setup: setup)
    }

    /// Block time of what is being heard right now (for display only, never for grading).
    func heardTime() -> Double? {
        clock.map { $0.blockTime(forUptime: ProcessInfo.processInfo.systemUptime) - latency }
    }

    /// Key, pad or MIDI press; ignored when not running.
    func tap(_ event: TapEvent) {
        guard isRunning, let clock, event.isDown else { return }
        let time = clock.blockTime(forUptime: event.timestamp) - latency - setup.offsets[event.source]
        // a double trigger: no sound, not counted
        let isPulse = event.key == .pulse
        if let last = lastTap[isPulse], time - last < OnsetGraderPolicy.debounce { return }
        lastTap[isPulse] = time
        if setup.tapSound { player?.playTap() }
        if event.key == .pulse {
            pulseTaps.append(time)
        } else {
            taps.append(time)
            tapSources.append(event.source)
            tapCount += 1
        }
    }

    func stop() {
        keys.stop()
        midi.stop()
        isRunning = false
    }

    func cancel() { stop() }
}
