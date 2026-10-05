import AudiateCore
import AVFoundation

/// One AVAudioEngine with a node for pre-mixed blocks and a node for immediate tap feedback.
@MainActor
public final class BlockPlayer {
    public let bank: SampleBank
    private let engine = AVAudioEngine()
    private let blockNode = AVAudioPlayerNode()
    private let tapNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let tapBuffer: AVAudioPCMBuffer?
    /// Incremented per block so a stopped block's completion is ignored.
    private var generation = 0
    private var configObserver: NSObjectProtocol?

    /// Time from "schedule" to the first sample, so the whole block is queued before it starts.
    public static let startLead = 0.15

    public init(bank: SampleBank) throws {
        self.bank = bank
        guard let format = AVAudioFormat(standardFormatWithSampleRate: bank.sampleRate, channels: 1) else {
            throw AudioError.unsupportedFormat("mono \(bank.sampleRate) Hz")
        }
        self.format = format
        tapBuffer = bank.samples[SampleBank.tapSampleName].flatMap { Self.buffer($0, format: format) }
        for node in [blockNode, tapNode] {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        try engine.start()
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { try? self?.engine.start() }
        }
    }

    /// Audio reaches the ear this much later than its scheduled host time.
    public var outputLatency: Double {
        engine.outputNode.presentationLatency + (OutputDevice.current()?.ioBufferDuration ?? 0)
    }

    /// Mixes and schedules the whole timeline; returns the clock anchored at its first sample.
    @discardableResult
    public func play(_ timeline: Timeline, onFinish: @escaping @MainActor () -> Void) throws -> BlockClock {
        let samples = try BlockMixer.mix(timeline.sounds, duration: timeline.duration, bank: bank)
        return try play(samples: samples, onFinish: onFinish)
    }

    @discardableResult
    public func play(samples: [Float], onFinish: @escaping @MainActor () -> Void) throws -> BlockClock {
        guard let buffer = Self.buffer(samples, format: format) else { throw AudioError.bufferAllocation }
        stop()
        if !engine.isRunning { try engine.start() }
        generation += 1
        let current = generation
        blockNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                onFinish()
            }
        }
        let anchor = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.startLead)
        blockNode.play(at: AVAudioTime(hostTime: anchor))
        return BlockClock(anchorHostTime: anchor)
    }

    public func stop() {
        generation += 1
        blockNode.stop()
    }

    /// Chunks kept queued ahead of playback (~0.28 s at 44.1 kHz with 2048-frame chunks).
    public static let queuedChunks = 6

    /// Plays an open-ended stream. `provider(from, to)` returns the sounds starting in `[from, to)`,
    /// or nil once the stream has ended; it is called on the main actor about `queuedChunks` chunks
    /// ahead of what is heard. Returns the clock anchored at the stream's first sample.
    @discardableResult
    public func stream(provider: @escaping @MainActor (Double, Double) -> [ScheduledSound]?,
                       onFinish: @escaping @MainActor () -> Void) throws -> BlockClock {
        stop()
        if !engine.isRunning { try engine.start() }
        generation += 1
        stream = Stream(renderer: StreamRenderer(bank: bank), provider: provider, onFinish: onFinish)
        for _ in 0..<Self.queuedChunks { scheduleNextChunk(generation) }
        let anchor = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: Self.startLead)
        blockNode.play(at: AVAudioTime(hostTime: anchor))
        return BlockClock(anchorHostTime: anchor)
    }

    private struct Stream {
        var renderer: StreamRenderer
        let provider: @MainActor (Double, Double) -> [ScheduledSound]?
        let onFinish: @MainActor () -> Void
        var ended = false
    }

    private var stream: Stream?

    private func scheduleNextChunk(_ current: Int) {
        guard generation == current, var s = stream else { return }
        var sounds: [ScheduledSound] = []
        if !s.ended {
            let range = s.renderer.nextRange
            if let next = s.provider(range.from, range.to) { sounds = next } else { s.ended = true }
        }
        guard let samples = try? s.renderer.render(adding: sounds), let buffer = Self.buffer(samples, format: format) else { return }
        let last = s.ended && !s.renderer.isRinging
        let onFinish = s.onFinish
        stream = s
        blockNode.scheduleBuffer(buffer, at: nil, options: [], completionCallbackType: last ? .dataPlayedBack : .dataConsumed) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                if last { onFinish() } else { self.scheduleNextChunk(current) }
            }
        }
    }

    /// Short click on keyDown for low-latency monitoring.
    public func playTap() {
        guard let tapBuffer, engine.isRunning else { return }
        tapNode.scheduleBuffer(tapBuffer, at: nil, options: .interrupts)
        if !tapNode.isPlaying { tapNode.play() }
    }

    nonisolated static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(samples.count, 1))),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        return buffer
    }
}
