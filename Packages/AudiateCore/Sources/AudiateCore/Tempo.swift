/// Tempo in BPM of the meter's counting unit (docs/02-curriculum.md §7):
/// macrobeats for usual meters, the eighth (= microbeat) for unusual meters.
public struct Tempo: Codable, Hashable, Sendable {
    public let bpm: Double

    public init(bpm: Double) {
        self.bpm = bpm
    }

    public static func standard(for meter: Meter) -> Tempo {
        Tempo(bpm: meter.isUnusual ? TempoPolicy.unusualEighthBPM : (meter.macrobeats.first == 3 ? TempoPolicy.tripleBPM : TempoPolicy.dupleBPM))
    }

    public func secondsPerTick(in meter: Meter) -> Double {
        let microbeatsPerBeat = meter.isUnusual ? 1 : (meter.macrobeats.first ?? 1)
        return 60 / (bpm * Double(microbeatsPerBeat * Rhythm.ticksPerMicrobeat))
    }

    public func seconds(forTicks ticks: Int, in meter: Meter) -> Double {
        Double(ticks) * secondsPerTick(in: meter)
    }
}
