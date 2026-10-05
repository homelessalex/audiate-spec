import AudiateCore

/// Renders a whole block into one mono buffer, each sound placed at an exact sample offset.
///
/// Scheduling one pre-mixed buffer (instead of many player-node buffers) makes the relative
/// timing of every sound in the block sample-accurate by construction.
public enum BlockMixer {
    /// Fade applied at the end of a sustained sound, like closing a hi-hat.
    public static let chokeSeconds = 0.010

    public static func mix(_ sounds: [ScheduledSound], duration: Double, bank: SampleBank) throws -> [Float] {
        let placed = try sounds.map { (offset: frame(for: $0.time, rate: bank.sampleRate), samples: try voice(for: $0, bank: bank)) }
        let length = placed.map { $0.offset + $0.samples.count }.reduce(frame(for: duration, rate: bank.sampleRate), max)
        var out = [Float](repeating: 0, count: length)
        for (offset, samples) in placed {
            for (k, v) in samples.enumerated() {
                out[offset + k] += v
            }
        }
        limit(&out)
        return out
    }

    /// The sample a sound plays: cut at its duration with a choke fade when it sustains.
    public static func voice(for sound: ScheduledSound, bank: SampleBank) throws -> [Float] {
        guard let sample = bank.samples[sound.sound.sampleName] else { throw AudioError.missingSample(sound.sound.sampleName) }
        guard let sustain = sound.duration else { return sample }
        let length = min(sample.count, max(1, frame(for: sustain, rate: bank.sampleRate)))
        let fade = min(frame(for: chokeSeconds, rate: bank.sampleRate), length / 2)
        var out = Array(sample.prefix(length))
        for k in (length - fade)..<length {
            out[k] *= Float(length - k) / Float(fade + 1)
        }
        return out
    }

    /// Overlaps are rare and short; hard-limit instead of normalizing so levels stay consistent.
    static func limit(_ out: inout [Float]) {
        for i in out.indices where abs(out[i]) > 1 {
            out[i] = out[i] > 0 ? 1 : -1
        }
    }

    public static func frame(for seconds: Double, rate: Double) -> Int {
        Int((seconds * rate).rounded())
    }
}
