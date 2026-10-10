extension Timeline {
    /// `| count-in | look | hear it inside | measure 1 | … | measure n |`: a phrase read from notation (E13).
    /// Nothing but the click sounds; one response slot per measure, each graded on its own.
    public static func phraseBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage,
                                   lookMeasures: Int = EchoPolicy.readLookMeasures) throws -> Timeline {
        guard let first = patterns.first else { throw TimelineError.emptyBlock }
        let meter = first.meter
        guard patterns.allSatisfy({ $0.meter == meter }) else { throw TimelineError.mixedMeters }
        guard patterns.allSatisfy({ $0.pickupTicks == 0 }) else { throw TimelineError.pickupInPhrase }

        let spt = tempo.secondsPerTick(in: meter)
        let measure = Double(meter.measureTicks) * spt
        func time(measure m: Int, tick: Int) -> Double { Double(m) * measure + Double(tick) * spt }

        let look = max(1, lookMeasures)
        let roles: [MeasureRole] = [.countIn, .prompt(0)] + Array(repeating: .hold(0), count: look - 1)
            + patterns.indices.map { .response($0) }
        let firstResponse = 1 + look

        // Count-in: macro + micro beats; afterwards per click stage (stage C: macrobeats while looking only).
        var sounds: [ScheduledSound] = []
        for m in roles.indices {
            for span in meter.macrobeatSpans {
                for micro in 0..<span.microbeats {
                    let tick = span.startTick + micro * Rhythm.ticksPerMicrobeat
                    let byStage = (clickStage.clicksAfterCountIn && (micro == 0 || clickStage.clicksMicrobeats))
                        || (clickStage == .c && m > 0 && m < firstResponse && micro == 0)
                    guard m == 0 || byStage else { continue }
                    sounds.append(ScheduledSound(time: time(measure: m, tick: tick), sound: .click(tick: tick, micro: micro)))
                }
            }
        }

        let responses = patterns.enumerated().map { i, pattern in
            ResponseSlot(patternID: pattern.id, start: time(measure: firstResponse + i, tick: 0),
                         end: time(measure: firstResponse + i + 1, tick: 0),
                         expectedOnsets: pattern.onsets.map { time(measure: firstResponse + i, tick: $0.startTick) },
                         macrobeatTimes: meter.macrobeatSpans.map { time(measure: firstResponse + i, tick: $0.startTick) })
        }
        let prompt = PromptSlot(patternID: first.id, start: time(measure: 1, tick: 0), end: time(measure: firstResponse, tick: 0), cues: [])
        return Timeline(sounds: sounds, measureRoles: roles, prompts: [prompt], responses: responses, measureDuration: measure,
                        duration: Double(roles.count) * measure)
    }
}
