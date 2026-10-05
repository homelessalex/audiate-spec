extension Timeline {
    /// `| count-in | prompt 1 | response 1 | prompt 2 | response 2 | … |` without stopping the pulse.
    /// A pickup sits at the end of the preceding measure; the count-in stops where it begins.
    public static func echoBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage,
                                 deriver: SyllableDeriver = SyllableDeriver()) throws -> Timeline {
        guard let first = patterns.first else { throw TimelineError.emptyBlock }
        let meter = first.meter
        guard patterns.allSatisfy({ $0.meter == meter }) else { throw TimelineError.mixedMeters }

        let spt = tempo.secondsPerTick(in: meter)
        let measure = Double(meter.measureTicks) * spt
        func time(measure m: Int, tick: Int) -> Double { Double(m) * measure + Double(tick) * spt }

        var sounds: [ScheduledSound] = []
        let measureCount = 1 + 2 * patterns.count
        let countInEnd = meter.measureTicks - first.pickupTicks

        // Count-in: macro + micro beats (establishes meter type); afterwards per click stage.
        for m in 0..<measureCount {
            for span in meter.macrobeatSpans {
                for micro in 0..<span.microbeats {
                    let tick = span.startTick + micro * Rhythm.ticksPerMicrobeat
                    let byStage = clickStage.clicksAfterCountIn && (micro == 0 || clickStage.clicksMicrobeats)
                    let byCountIn = m == 0 && tick < countInEnd
                    guard byStage || byCountIn else { continue }
                    sounds.append(ScheduledSound(time: time(measure: m, tick: tick), sound: .click(accented: micro == 0)))
                }
            }
        }

        var prompts: [PromptSlot] = []
        var responses: [ResponseSlot] = []
        for (i, pattern) in patterns.enumerated() {
            let promptMeasure = 1 + 2 * i
            for (index, event) in pattern.events.enumerated() where event.isOnset {
                sounds.append(ScheduledSound(time: time(measure: promptMeasure, tick: event.startTick), sound: .hiHat,
                                             duration: Double(Self.soundingTicks(pattern.events, from: index)) * spt))
            }
            prompts.append(PromptSlot(
                patternID: pattern.id,
                start: time(measure: promptMeasure, tick: -pattern.pickupTicks),
                end: time(measure: promptMeasure + 1, tick: 0),
                cues: try pattern.events.map { event in
                    SyllableCue(time: time(measure: promptMeasure, tick: event.startTick), duration: Double(event.ticks) * spt,
                                text: try deriver.display(for: event, in: meter), kind: event.kind)
                }
            ))
            let responseMeasure = promptMeasure + 1
            responses.append(ResponseSlot(
                patternID: pattern.id,
                start: time(measure: responseMeasure, tick: -pattern.pickupTicks),
                end: time(measure: responseMeasure + 1, tick: 0),
                expectedOnsets: pattern.onsets.map { time(measure: responseMeasure, tick: $0.startTick) },
                macrobeatTimes: meter.macrobeatSpans.map { time(measure: responseMeasure, tick: $0.startTick) }
            ))
        }

        // Stable sort keeps clicks before prompt notes at equal times.
        let sorted = sounds.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
        return Timeline(sounds: sorted, prompts: prompts, responses: responses, measureDuration: measure,
                        duration: Double(measureCount) * measure)
    }

    /// A note sounds through the continuations tied to it.
    static func soundingTicks(_ events: [RhythmEvent], from index: Int) -> Int {
        var ticks = events[index].ticks
        var i = index
        while events[i].tieToNext, i + 1 < events.count {
            i += 1
            ticks += events[i].ticks
        }
        return ticks
    }
}
