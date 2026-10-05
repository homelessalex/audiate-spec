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
        let t = try Timeline.echoBlock(patterns: [p, p, p], tempo: Tempo(bpm: bpm), clickStage: .a, voice: .neutral)
        let clicks = t.sounds.filter { !$0.sound.isVoice }
        return (Timeline(sounds: clicks, responses: [], measureDuration: t.measureDuration, duration: t.duration), clicks)
    }

    @Test func bankHasEverySoundTheTimelineUses() {
        let table = SyllableTable.standard
        let syllables = Set(table.usualDuple + table.usualTriple + table.unusualDuple + table.unusualTriple + table.thirds + [table.division])
        let needed = syllables.map { Sound.syllable($0).sampleName }
            + [Sound.neutral, .click(accented: true), .click(accented: false)].map(\.sampleName) + [SampleBank.tapSampleName]
        for name in needed {
            #expect(Self.bank.samples[name] != nil, "\(name)")
        }
        #expect(Self.bank.samples.values.allSatisfy { $0.count <= Int(Self.bank.sampleRate * 0.25) + 1 })
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
