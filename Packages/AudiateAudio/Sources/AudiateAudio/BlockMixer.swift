import AudiateCore

/// Renders a whole block into one mono buffer, each sound placed at an exact sample offset.
///
/// Scheduling one pre-mixed buffer (instead of many player-node buffers) makes the relative
/// timing of every sound in the block sample-accurate by construction.
public enum BlockMixer {
    /// Fade applied at the end of a sustained sound, like closing a hi-hat.
    public static let chokeSeconds = 0.010

    public static func mix(_ sounds: [ScheduledSound], duration: Double, bank: SampleBank) throws -> [Float] {
        let rate = bank.sampleRate
        let placed = try sounds.map { s -> (offset: Int, sample: ArraySlice<Float>, fade: Int) in
            guard let sample = bank.samples[s.sound.sampleName] else { throw AudioError.missingSample(s.sound.sampleName) }
            guard let sustain = s.duration else { return (frame(for: s.time, rate: rate), sample[...], 0) }
            let length = min(sample.count, max(1, frame(for: sustain, rate: rate)))
            return (frame(for: s.time, rate: rate), sample.prefix(length), min(frame(for: chokeSeconds, rate: rate), length / 2))
        }
        let length = placed.map { $0.offset + $0.sample.count }.reduce(frame(for: duration, rate: rate), max)
        var out = [Float](repeating: 0, count: length)
        for (offset, sample, fade) in placed {
            let fadeStart = sample.count - fade
            for (i, v) in zip(sample.indices, sample) {
                let k = i - sample.startIndex
                let gain: Float = k < fadeStart ? 1 : Float(sample.count - k) / Float(fade + 1)
                out[offset + k] += v * gain
            }
        }
        // Overlaps are rare and short; hard-limit instead of normalizing so levels stay consistent.
        for i in out.indices where abs(out[i]) > 1 {
            out[i] = out[i] > 0 ? 1 : -1
        }
        return out
    }

    public static func frame(for seconds: Double, rate: Double) -> Int {
        Int((seconds * rate).rounded())
    }
}
