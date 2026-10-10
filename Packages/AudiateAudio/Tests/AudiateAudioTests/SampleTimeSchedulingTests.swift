import AudiateCore
import AVFoundation
import Testing
@testable import AudiateAudio

/// The stream feeder places every chunk at its own sample time on the player's timeline, so a chunk that
/// comes late cannot shift the ones after it. Checked through a real AVAudioEngine (offline rendering).
@Suite("Sample-time scheduling")
struct SampleTimeSchedulingTests {
    @Test func chunksPlayAtTheirSampleTimeWithAGapBetween() throws {
        let rate = 48_000.0
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
        try engine.start()
        func impulse() -> AVAudioPCMBuffer {
            var samples = [Float](repeating: 0, count: 256)
            samples[0] = 0.9
            return BlockPlayer.buffer(samples, format: format)!
        }
        // chunks at 1000 and 5000; nothing scheduled between (as after a skipped, late chunk)
        player.scheduleBuffer(impulse(), at: AVAudioTime(sampleTime: 1000, atRate: rate))
        player.scheduleBuffer(impulse(), at: AVAudioTime(sampleTime: 5000, atRate: rate))
        player.play()
        let chunk = try #require(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 1024))
        var out: [Float] = []
        while out.count < 8000 {
            guard try engine.renderOffline(1024, to: chunk) == .success else { break }
            out += UnsafeBufferPointer(start: chunk.floatChannelData![0], count: Int(chunk.frameLength))
        }
        engine.stop()
        let onsets = out.indices.filter { abs(out[$0]) > 0.1 && ($0 == 0 || abs(out[$0 - 1]) <= 0.1) }
        #expect(onsets == [1000, 5000])
    }
}

@Suite("Stream feeder")
struct StreamFeederTests {
    /// The feeder through a real engine: decided clicks, then the continuation, then a newer plan
    /// adding a note — every sound on its exact frame.
    @Test func playsThePlanThenTheContinuationOnExactFrames() async throws {
        let bank = BlockTimingTests.bank
        let rate = bank.sampleRate
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 1024)
        try engine.start()

        let click = ScheduledSound(time: 0, sound: .click(tick: 0, micro: 0))
        let decided = [0.1, 0.6].map { ScheduledSound(time: $0, sound: click.sound) }
        let continuation = ClickContinuation(gridStart: 0.1, measure: 0.5, clicks: [click])
        let plan = StreamPlan(sounds: decided, decidedUntil: 0.8, endTime: nil, continuation: continuation)
        // anchored far ahead: offline rendering has no real-time clock to fall behind
        let feeder = StreamFeeder(node: player, format: format, bank: bank, plan: plan,
                                  anchorHostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 3600), onFinish: {})
        feeder.prime()
        player.play()

        let chunk = try #require(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 1024))
        var out: [Float] = []
        var updated = false
        while Double(out.count) / rate < 2.4 {
            guard try engine.renderOffline(1024, to: chunk) == .success else { break }
            out += UnsafeBufferPointer(start: chunk.floatChannelData![0], count: Int(chunk.frameLength))
            if !updated, Double(out.count) / rate > 0.9 {
                // decided late: a note at 1.85 and the grid going on
                let note = ScheduledSound(time: 1.85, sound: .hiHat, duration: 0.1)
                feeder.update(StreamPlan(sounds: decided + [note] + [1.1, 1.6, 2.1].map { ScheduledSound(time: $0, sound: click.sound) },
                                         decidedUntil: 2.2, endTime: nil, continuation: continuation))
                updated = true
            }
            try await Task.sleep(for: .milliseconds(2)) // let the feeder's queue refill
        }
        engine.stop()
        // sample for sample what mixing the same sounds in one go gives
        let sounds = [0.1, 0.6, 1.1, 1.6, 2.1].map { ScheduledSound(time: $0, sound: click.sound) }
            + [ScheduledSound(time: 1.85, sound: .hiHat, duration: 0.1)]
        let reference = try BlockMixer.mix(sounds, duration: 2.3, bank: bank)
        // the engine's mixer pans the mono node into the output at −3 dB
        let gain = Float(0.5.squareRoot())
        let n = min(reference.count, out.count)
        let worst = zip(out.prefix(n), reference.prefix(n)).map { abs($0 - $1 * gain) }.max() ?? 1
        #expect(worst < 1e-3, "differs by \(worst)")
        #expect(feeder.stats.underruns == 0)
        #expect(feeder.stats.lostSounds == 0)
    }
}
