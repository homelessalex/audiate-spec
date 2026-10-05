extension Timeline {
    /// "Model vs. you" (docs/04-exercises.md §1): count-in, the model in one measure, the learner's taps
    /// in the next, macrobeat clicks throughout. Taps are given in seconds from the response measure's
    /// downbeat; each sounds until the next tap or the end of the measure.
    public static func replay(pattern: Pattern, tempo: Tempo, tapsFromDownbeat: [Double]) throws -> Timeline {
        let model = try block(patterns: [pattern], tempo: tempo, clickStage: .b, responses: false, deriver: SyllableDeriver())
        let measure = model.measureDuration
        let downbeat = 2 * measure
        let taps = tapsFromDownbeat.sorted().filter { $0 > -measure && $0 < measure }
        let yours = taps.enumerated().map { i, t in
            let next = i + 1 < taps.count ? taps[i + 1] : measure
            return ScheduledSound(time: downbeat + t, sound: .hiHat, duration: next - t)
        }
        let clicks = pattern.meter.macrobeatSpans.map {
            ScheduledSound(time: downbeat + tempo.seconds(forTicks: $0.startTick, in: pattern.meter), sound: .click(accented: true))
        }
        let sounds = (model.sounds + clicks + yours).enumerated()
            .sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
        return Timeline(sounds: sounds, prompts: model.prompts, measureDuration: measure, duration: 3 * measure)
    }
}
