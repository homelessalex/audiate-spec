import AudiateCore

/// Mixes an open-ended stream chunk by chunk. Sounds are supplied just before they are due, so what
/// comes next can still be decided while earlier audio plays. Output is identical to BlockMixer.
public struct StreamRenderer: Sendable {
    public let bank: SampleBank
    public let chunkFrames: Int
    /// Frames rendered so far.
    public private(set) var position = 0
    private var voices: [(start: Int, samples: [Float])] = []

    public init(bank: SampleBank, chunkFrames: Int = 2048) {
        self.bank = bank
        self.chunkFrames = chunkFrames
    }

    /// Stream time covered by the next chunk.
    public var nextRange: (from: Double, to: Double) {
        (Double(position) / bank.sampleRate, Double(position + chunkFrames) / bank.sampleRate)
    }

    /// True while sounds already started are still ringing.
    public var isRinging: Bool { !voices.isEmpty }

    /// Renders the next chunk with `sounds` (those starting in `nextRange`) added.
    public mutating func render(adding sounds: [ScheduledSound]) throws -> [Float] {
        for sound in sounds {
            let start = max(BlockMixer.frame(for: sound.time, rate: bank.sampleRate), position)
            voices.append((start, try BlockMixer.voice(for: sound, bank: bank)))
        }
        var out = [Float](repeating: 0, count: chunkFrames)
        let end = position + chunkFrames
        for voice in voices {
            let from = max(voice.start, position), to = min(voice.start + voice.samples.count, end)
            guard from < to else { continue }
            for frame in from..<to {
                out[frame - position] += voice.samples[frame - voice.start]
            }
        }
        voices.removeAll { $0.start + $0.samples.count <= end }
        position = end
        BlockMixer.limit(&out)
        return out
    }
}
