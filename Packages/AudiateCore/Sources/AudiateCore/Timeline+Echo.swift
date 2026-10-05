extension Timeline {
    /// `| count-in | prompt 1 | response 1 | prompt 2 | response 2 | … |` without stopping the pulse.
    /// A pickup sits at the end of the preceding measure; the count-in voice stops where it begins.
    public static func echoBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage, voice: PromptVoice,
                                 deriver: SyllableDeriver = SyllableDeriver()) throws -> Timeline {
        guard let first = patterns.first else { throw TimelineError.emptyBlock }
        let meter = first.meter
        guard patterns.allSatisfy({ $0.meter == meter }) else { throw TimelineError.mixedMeters }

        let spt = tempo.secondsPerTick(in: meter)
        let measure = Double(meter.measureTicks) * spt
        func time(measure m: Int, tick: Int) -> Double { Double(m) * measure + Double(tick) * spt }

        var sounds: [ScheduledSound] = []
        let measureCount = 1 + 2 * patterns.count

        // Clicks: count-in always; afterwards per stage.
        for m in 0..<measureCount where m == 0 || clickStage.clicksAfterCountIn {
            for span in meter.macrobeatSpans {
                for micro in 0..<span.microbeats where micro == 0 || clickStage.clicksMicrobeats {
                    let tick = span.startTick + micro * Rhythm.ticksPerMicrobeat
                    sounds.append(ScheduledSound(time: time(measure: m, tick: tick), sound: .click(accented: micro == 0)))
                }
            }
        }

        // Count-in voice: macrobeats in usual meters, every microbeat in unusual ones.
        let countInEnd = meter.measureTicks - first.pickupTicks
        for span in meter.macrobeatSpans {
            for micro in 0..<span.microbeats where micro == 0 || meter.isUnusual {
                let tick = span.startTick + micro * Rhythm.ticksPerMicrobeat
                guard tick < countInEnd else { continue }
                sounds.append(ScheduledSound(time: time(measure: 0, tick: tick),
                                             sound: .syllable(try deriver.syllable(in: meter, atTick: tick))))
            }
        }

        var responses: [ResponseSlot] = []
        for (i, pattern) in patterns.enumerated() {
            let promptMeasure = 1 + 2 * i
            for event in pattern.events where event.isOnset {
                let sound: Sound = voice == .neutral
                    ? .neutral
                    : .syllable(try deriver.syllable(in: meter, atTick: event.startTick))
                sounds.append(ScheduledSound(time: time(measure: promptMeasure, tick: event.startTick), sound: sound))
            }
            let responseMeasure = promptMeasure + 1
            responses.append(ResponseSlot(
                patternID: pattern.id,
                start: time(measure: responseMeasure, tick: -pattern.pickupTicks),
                end: time(measure: responseMeasure + 1, tick: 0),
                expectedOnsets: pattern.onsets.map { time(measure: responseMeasure, tick: $0.startTick) },
                macrobeatTimes: meter.macrobeatSpans.map { time(measure: responseMeasure, tick: $0.startTick) }
            ))
        }

        // Stable sort keeps clicks before voices at equal times.
        let sorted = sounds.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
        return Timeline(sounds: sorted, responses: responses, measureDuration: measure,
                        duration: Double(measureCount) * measure)
    }
}
