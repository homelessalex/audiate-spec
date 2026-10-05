import AudiateCore

/// Renders a whole block into one mono buffer, each sound placed at an exact sample offset.
///
/// Scheduling one pre-mixed buffer (instead of many player-node buffers) makes the relative
/// timing of every sound in the block sample-accurate by construction.
public enum BlockMixer {
    public static func mix(_ sounds: [ScheduledSound], duration: Double, bank: SampleBank) throws -> [Float] {
        let placed = try sounds.map { s -> (offset: Int, sample: [Float]) in
            guard let sample = bank.samples[s.sound.sampleName] else { throw AudioError.missingSample(s.sound.sampleName) }
            return (frame(for: s.time, rate: bank.sampleRate), sample)
        }
        let length = placed.map { $0.offset + $0.sample.count }.reduce(frame(for: duration, rate: bank.sampleRate), max)
        var out = [Float](repeating: 0, count: length)
        for (offset, sample) in placed {
            for (i, v) in sample.enumerated() {
                out[offset + i] += v
            }
        }
        // Overlaps are rare and short; soft-clip instead of normalizing so levels stay consistent.
        for i in out.indices where abs(out[i]) > 1 {
            out[i] = out[i] > 0 ? 1 : -1
        }
        return out
    }

    public static func frame(for seconds: Double, rate: Double) -> Int {
        Int((seconds * rate).rounded())
    }
}
