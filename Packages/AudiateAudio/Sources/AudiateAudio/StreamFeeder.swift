import AudiateCore
import AVFoundation
import os

/// Plays an open-ended stream from its own queue (docs/05-architecture.md §3). It renders chunk after chunk
/// from the current `StreamPlan` and schedules each at its own sample time, a fixed lead ahead of what is
/// heard; the main thread takes no part, so a busy or hung UI can't delay, drop or shift the pulse.
/// The UI hands over a new plan when it has decided something (`update`), placing new material after
/// `notBefore`; past the decided part the plan's continuation keeps clicking.
///
/// If the queue itself ever falls behind real time, the late part is skipped rather than played late,
/// so everything after stays on the clock the UI and the grading use.
public final class StreamFeeder: @unchecked Sendable {
    public static let chunkFrames = 1024
    /// Chunks kept scheduled ahead of playback (~0.17 s at 48 kHz).
    public static let queuedChunks = 8
    /// Room left between where the audio has rendered and anything newly decided.
    public static let safetyMargin = 0.05

    private static let log = Logger(subsystem: "app.audiate", category: "stream")

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "app.audiate.stream", qos: .userInteractive)
    private let node: AVAudioPlayerNode
    private let format: AVAudioFormat
    private let rate: Double
    private let anchorSeconds: Double
    private let onFinish: @MainActor @Sendable () -> Void

    // Guarded by `lock`.
    private var plan: StreamPlan
    private var renderer: StreamRenderer
    private var queued = 0
    private var ended = false
    private var finishing = false
    private var cancelled = false
    private var underrunCount = 0
    private var lostSoundCount = 0

    init(node: AVAudioPlayerNode, format: AVAudioFormat, bank: SampleBank, plan: StreamPlan, anchorHostTime: UInt64,
         onFinish: @escaping @MainActor @Sendable () -> Void) {
        self.node = node
        self.format = format
        rate = bank.sampleRate
        anchorSeconds = AVAudioTime.seconds(forHostTime: anchorHostTime)
        self.plan = plan
        renderer = StreamRenderer(bank: bank, chunkFrames: Self.chunkFrames)
        self.onFinish = onFinish
    }

    /// Fills the queue before playback starts.
    func prime() {
        lock.withLock { fill() }
    }

    /// A newer snapshot. What it places before the rendered position is too late to play (it should
    /// not: the UI keeps new material after `notBefore`); lost notes are counted and logged.
    public func update(_ newPlan: StreamPlan) {
        lock.withLock {
            let rendered = renderedSeconds
            let lost = newPlan.sounds.filter { $0.sound == .hiHat && $0.time >= plan.decidedUntil && $0.time < rendered }.count
            if lost > 0 {
                lostSoundCount += lost
                Self.log.error("decision came late: \(lost) note(s) before the rendered position \(rendered, format: .fixed(precision: 3))")
            }
            plan = newPlan
        }
    }

    /// The earliest time something newly decided may start.
    public var notBefore: Double {
        lock.withLock { renderedSeconds } + Self.safetyMargin
    }

    /// Times the queue fell behind real time (a stretch was skipped), and notes decided too late to play.
    public var stats: (underruns: Int, lostSounds: Int) {
        lock.withLock { (underrunCount, lostSoundCount) }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }

    // MARK: - On the queue

    private var renderedSeconds: Double { Double(renderer.position) / rate }

    private func nowSeconds() -> Double {
        AVAudioTime.seconds(forHostTime: mach_absolute_time()) - anchorSeconds
    }

    /// Lock held.
    private func fill() {
        while !cancelled, !finishing, queued < Self.queuedChunks {
            renderChunk()
        }
    }

    /// Lock held.
    private func renderChunk() {
        let now = nowSeconds()
        if now > 0, renderedSeconds < now + 0.003 {
            let resume = Int(((now + 0.01) * rate).rounded(.up))
            underrunCount += 1
            Self.log.error("audio fell behind by \(now - self.renderedSeconds, format: .fixed(precision: 3)) s; skipped ahead")
            renderer.skip(to: resume)
        }
        let start = renderer.position
        var sounds: [ScheduledSound] = []
        if !ended {
            let range = renderer.nextRange
            if let next = plan.sounds(from: range.from, to: range.to) { sounds = next } else { ended = true }
        }
        guard let samples = try? renderer.render(adding: sounds), let buffer = BlockPlayer.buffer(samples, format: format) else {
            finishing = true
            return
        }
        let last = ended && !renderer.isRinging
        if last { finishing = true }
        queued += 1
        node.scheduleBuffer(buffer, at: AVAudioTime(sampleTime: AVAudioFramePosition(start), atRate: rate), options: [],
                            completionCallbackType: last ? .dataPlayedBack : .dataConsumed) { [self] _ in
            queue.async { self.chunkDone(last: last) }
        }
    }

    private func chunkDone(last: Bool) {
        lock.withLock {
            queued -= 1
            guard !cancelled else { return }
            if last {
                let onFinish = self.onFinish
                Task { @MainActor in onFinish() }
            } else {
                fill()
            }
        }
    }
}
