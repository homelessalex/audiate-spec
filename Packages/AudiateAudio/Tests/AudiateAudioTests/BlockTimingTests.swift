import AudiateCore
import AVFoundation
import Foundation
import Testing
@testable import AudiateAudio

/// Click timing check for docs/06 M1: sounds land on exact sample frames, also after a pass
/// through AVAudioEngine (offline manual rendering). Hardware loopback: docs/timing-verification.md.
@Suite("Block timing")
struct BlockTimingTests {
    static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let bank: SampleBank = {
        do { return try SampleBank.load(directory: root.appendingPathComponent("Resources/Samples")) }
        catch { fatalError("samples: \(error)") }
    }()
    static let library: PatternLibrary = {
        let data = root.appendingPathComponent("data")
        do {
            return try PatternLibrary(patternsJSON: Data(contentsOf: data.appendingPathComponent("patterns.json")),
                                      cellsJSON: Data(contentsOf: data.appendingPathComponent("cells.json")))
        } catch { fatalError("library: \(error)") }
    }()

    func clickTimeline(_ id: String, bpm: Double) throws -> (timeline: Timeline, clicks: [ScheduledSound]) {
        let p = try #require(Self.library.pattern(id: id))
        let t = try Timeline.echoBlock(patterns: [p, p, p], tempo: Tempo(bpm: bpm), clickStage: .a)
        let clicks = t.sounds.filter { $0.sound != .hiHat }
        return (Timeline(sounds: clicks, measureDuration: t.measureDuration, duration: t.duration), clicks)
    }

    @Test func bankHasEverySound() {
        let needed = [Sound.hiHat, .click(accented: true), .click(accented: false)].map(\.sampleName) + [SampleBank.tapSampleName]
        for name in needed {
            #expect(Self.bank.samples[name] != nil, "\(name)")
        }
        // long enough to sustain a dotted half at the slowest triple tempo
        let longest = try! Tempo(bpm: TempoPolicy.tripleRange.lowerBound).seconds(forTicks: 72, in: #require(Self.library.meters["usual_triple"]))
        #expect(Double(Self.bank.samples["hihat_open"]!.count) / Self.bank.sampleRate >= longest)
    }

    @Test func sustainedSoundsAreChokedAtTheirDuration() throws {
        let rate = Self.bank.sampleRate
        let sounds = [ScheduledSound(time: 0.1, sound: .hiHat, duration: 0.375)]
        let mixed = try BlockMixer.mix(sounds, duration: 1.0, bank: Self.bank)
        let start = BlockMixer.frame(for: 0.1, rate: rate), end = BlockMixer.frame(for: 0.475, rate: rate)
        #expect(mixed[..<start].allSatisfy { $0 == 0 })
        #expect(mixed[(end - BlockMixer.frame(for: 0.05, rate: rate))..<(end - BlockMixer.frame(for: 0.02, rate: rate))].contains { abs($0) > 0.01 })
        #expect(mixed[end...].allSatisfy { $0 == 0 })
        // without a duration the one-shot rings out
        let free = try BlockMixer.mix([ScheduledSound(time: 0, sound: .hiHat)], duration: 0.1, bank: Self.bank)
        #expect(free.count == Self.bank.samples["hihat_open"]!.count)
    }

    @Test func mixerPlacesSoundsOnExactFrames() throws {
        let (timeline, clicks) = try clickTimeline("D-DV-03", bpm: 80)
        let mixed = try BlockMixer.mix(timeline.sounds, duration: timeline.duration, bank: Self.bank)
        let onsets = Self.detectOnsets(mixed)
        // the detector fires where each click sample itself first crosses the threshold
        let lead = { (s: Sound) in Self.detectOnsets(Self.bank.samples[s.sampleName]!)[0] }
        #expect(onsets == clicks.map { BlockMixer.frame(for: $0.time, rate: Self.bank.sampleRate) + lead($0.sound) })
    }

    @Test(arguments: [("D-DV-03", 80.0), ("T-MM-04", 56.0), ("UU-MM-02", 200.0)])
    func engineRenderKeepsClickJitterUnderOneMillisecond(id: String, bpm: Double) throws {
        let (timeline, clicks) = try clickTimeline(id, bpm: bpm)
        let mixed = try BlockMixer.mix(timeline.sounds, duration: timeline.duration, bank: Self.bank)
        let (rendered, rate) = try Self.renderThroughEngine(mixed, sampleRate: Self.bank.sampleRate)
        let onsets = Self.detectOnsets(rendered).map { Double($0) / rate }
        try #require(onsets.count == clicks.count)
        // Constant engine offset is fine; deviations from it are jitter.
        let deviations = zip(onsets, clicks).map { $0 - $1.time }
        let offset = deviations[0]
        let jitter = deviations.map { abs($0 - offset) }.max()!
        #expect(jitter < 0.001, "jitter \(jitter * 1000) ms")
    }

    /// First frame above threshold after ≥ 10 ms below it.
    static func detectOnsets(_ x: [Float], threshold: Float = 0.05) -> [Int] {
        let quiet = Int(bank.sampleRate * 0.010)
        var onsets: [Int] = []
        var lastLoud = -quiet - 1
        for (i, v) in x.enumerated() where abs(v) > threshold {
            if i - lastLoud > quiet { onsets.append(i) }
            lastLoud = i
        }
        return onsets
    }

    /// Plays the buffer through AVAudioPlayerNode → main mixer in offline manual rendering mode.
    static func renderThroughEngine(_ samples: [Float], sampleRate: Double) throws -> ([Float], Double) {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let outFormat = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: outFormat, maximumFrameCount: 4096)
        try engine.start()
        let buffer = try #require(BlockPlayer.buffer(samples, format: format))
        player.scheduleBuffer(buffer, at: nil)
        player.play()

        let chunk = try #require(AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096))
        let total = Int(Double(samples.count) / sampleRate * outFormat.sampleRate) + 4096
        var out: [Float] = []
        while out.count < total {
            let status = try engine.renderOffline(4096, to: chunk)
            guard status == .success else { break }
            out += UnsafeBufferPointer(start: chunk.floatChannelData![0], count: Int(chunk.frameLength))
        }
        engine.stop()
        return (out, outFormat.sampleRate)
    }
}

@Suite("Stream rendering")
struct StreamRenderingTests {
    @Test func chunksMatchTheWholeBlockMix() throws {
        let p = try #require(BlockTimingTests.library.pattern(id: "D-TI-02"))
        let t = try Timeline.echoBlock(patterns: [p, p], tempo: Tempo(bpm: 80), clickStage: .a)
        let bank = BlockTimingTests.bank
        let whole = try BlockMixer.mix(t.sounds, duration: t.duration, bank: bank)

        var renderer = StreamRenderer(bank: bank, chunkFrames: 1000)
        var streamed: [Float] = []
        while streamed.count < whole.count {
            let range = renderer.nextRange
            streamed += try renderer.render(adding: t.sounds.filter { $0.time >= range.from && $0.time < range.to })
        }
        #expect(Array(streamed.prefix(whole.count)) == whole)
        #expect(streamed.dropFirst(whole.count).allSatisfy { $0 == 0 })
    }
}

@Suite("Key map")
struct KeyMapTests {
    @Test func rolesAndReservedKeys() {
        let map = KeyMap.standard
        #expect(map.role(for: 49) == .rhythm)   // Space
        #expect(map.role(for: 38) == .rhythm)   // J
        #expect(map.role(for: 3) == .pulse)     // F
        #expect(map.role(for: 0) == nil)        // A
        #expect(!KeyMap.isAllowed(36) && !KeyMap.isAllowed(53) && !KeyMap.isAllowed(18)) // Return, Esc, 1
        #expect(KeyMap.isAllowed(0))
        let custom = KeyMap(rhythm: [KeyBinding(keyCode: 0, label: "A")], pulse: [KeyBinding(keyCode: 1, label: "S")])
        #expect(custom.role(for: 0) == .rhythm && custom.role(for: 1) == .pulse && custom.role(for: 49) == nil)
    }
}
