/// Orders patterns within a unit: easy → moderate → difficult.
public enum DifficultyScorer {
    public static func score(_ pattern: Pattern) -> Double {
        let onsets = pattern.onsets
        let offMicrobeat = onsets.filter { $0.startTick % Rhythm.ticksPerMicrobeat != 0 }.count
        let syncopated = onsets.filter { isSyncopated($0, in: pattern.meter) }.count
        var score = DifficultyPolicy.onsetWeight * Double(onsets.count)
            + DifficultyPolicy.offMicrobeatWeight * Double(offMicrobeat)
            + DifficultyPolicy.syncopationWeight * Double(syncopated)
        score += DifficultyPolicy.contentWeight[pattern.content] ?? 0
        return score
    }

    public static func level(_ pattern: Pattern) -> DifficultyLevel {
        let s = score(pattern)
        if s < DifficultyPolicy.moderateFrom { return .easy }
        return s < DifficultyPolicy.difficultFrom ? .moderate : .difficult
    }

    /// 3 = macrobeat, 2 = microbeat, 1 = division or third.
    static func strength(atTick tick: Int, in meter: Meter) -> Int {
        let t = tick.floorMod(meter.measureTicks)
        if meter.macrobeatSpans.contains(where: { $0.startTick == t }) { return 3 }
        return t % Rhythm.ticksPerMicrobeat == 0 ? 2 : 1
    }

    /// Onset on a weaker grid point than a grid point it sustains through.
    static func isSyncopated(_ event: RhythmEvent, in meter: Meter) -> Bool {
        let own = strength(atTick: event.startTick, in: meter)
        return ((event.startTick + 1)..<event.endTick).contains { t in
            t.floorMod(Rhythm.divisionTicks) == 0 && strength(atTick: t, in: meter) > own
        }
    }
}
