extension Timeline {
    /// `| count-in | prompt 1 | hold | response 1 | prompt 2 | hold | response 2 | … |` without stopping the pulse.
    /// A pickup sits at the end of the preceding measure; the count-in stops where it begins.
    public static func echoBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage,
                                 gapMeasures: Int = EchoPolicy.gapMeasures,
                                 deriver: SyllableDeriver = SyllableDeriver()) throws -> Timeline {
        try block(patterns: patterns, tempo: tempo, clickStage: clickStage, promptSounds: true, gapMeasures: gapMeasures,
                  responses: true, deriver: deriver)
    }

    /// `| count-in | prompt 1 | prompt 2 | … |`: patterns to listen to, no response measures (E2, E3, E4).
    public static func listenBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage,
                                   deriver: SyllableDeriver = SyllableDeriver()) throws -> Timeline {
        try block(patterns: patterns, tempo: tempo, clickStage: clickStage, promptSounds: true, gapMeasures: 0,
                  responses: false, deriver: deriver)
    }

    /// `| count-in | look | hear it inside | read | look | … |`: reading from notation (E5). Nothing but the click
    /// sounds; each pattern is shown `lookMeasures` measures before it is read.
    public static func readBlock(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage,
                                 lookMeasures: Int = EchoPolicy.readLookMeasures,
                                 deriver: SyllableDeriver = SyllableDeriver()) throws -> Timeline {
        try block(patterns: patterns, tempo: tempo, clickStage: clickStage, promptSounds: false, gapMeasures: max(0, lookMeasures - 1),
                  responses: true, deriver: deriver)
    }

    static func block(patterns: [Pattern], tempo: Tempo, clickStage: ClickStage, promptSounds: Bool, gapMeasures: Int,
                      responses withResponses: Bool, deriver: SyllableDeriver) throws -> Timeline {
        guard let first = patterns.first else { throw TimelineError.emptyBlock }
        let meter = first.meter
        guard patterns.allSatisfy({ $0.meter == meter }) else { throw TimelineError.mixedMeters }

        let spt = tempo.secondsPerTick(in: meter)
        let measure = Double(meter.measureTicks) * spt
        func time(measure m: Int, tick: Int) -> Double { Double(m) * measure + Double(tick) * spt }

        var sounds: [ScheduledSound] = []
        let measuresPerPattern = withResponses ? 2 + gapMeasures : 1
        let measureCount = 1 + measuresPerPattern * patterns.count
        var roles: [MeasureRole] = [.countIn]
        for i in patterns.indices {
            roles.append(.prompt(i))
            if withResponses {
                roles += Array(repeating: .hold(i), count: gapMeasures)
                roles.append(.response(i))
            }
        }
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
            let promptMeasure = 1 + measuresPerPattern * i
            for (index, event) in pattern.events.enumerated() where event.isOnset && promptSounds {
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
            guard withResponses else { continue }
            let responseMeasure = promptMeasure + 1 + gapMeasures
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
        return Timeline(sounds: sorted, measureRoles: roles, prompts: prompts, responses: responses, measureDuration: measure,
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
