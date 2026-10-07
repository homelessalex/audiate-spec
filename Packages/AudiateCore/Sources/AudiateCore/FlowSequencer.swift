/// The session as one uninterrupted pulse (docs/04-exercises.md §1). Every tap attempt is
/// `| lead-in | prompt | hold | response |`; the measure right after a response is the next attempt's
/// lead-in, during which the verdict is shown — the click never stops. A change of meter or tempo adds
/// one count-in measure in the new tempo.
///
/// Other kinds: E10 `| lead-in | with click | silent × n |`; E2/E6 `| lead-in | prompt | prompt |` then the
/// pulse stops for the answer; E3 starts a fresh stream (its count-in gives only the macrobeat) and stops
/// for the answer; E7 is silent. After a stop the runner starts a new stream at the next attempt.
///
/// What follows an attempt (retry or next pattern) is decided when its outcome is reported. Until then
/// only the clicks of the following measure are fixed (`decidedUntil`); a pickup of the next prompt is
/// added later, so the outcome must be reported before playback is rendered that far.
public struct FlowSequencer: Sendable {
    public enum Kind: Hashable, Sendable {
        case echo
        /// Notation shown while the pattern plays, then read back (reading, teaching).
        case readWithModel
        /// Notation only, one look-ahead measure (reading, evaluation).
        case read
        case nameNotation
        case holdPulse
        case dictation
        case whichMeter
        case meterFromNotation
        case sameOrDifferent
        case answerDifferently
        case compose

        /// The pulse stops after the attempt until the learner answers.
        public var awaitsInput: Bool {
            [.nameNotation, .dictation, .whichMeter, .meterFromNotation, .sameOrDifferent, .compose].contains(self)
        }
        /// Begins a new stream instead of following the previous lead-in.
        public var startsFresh: Bool { self == .whichMeter || isSilent }
        /// Nothing sounds.
        public var isSilent: Bool { self == .meterFromNotation || self == .compose }
    }

    /// step / item within the step / try (1-based).
    public struct Position: Hashable, Sendable {
        public var step: Int
        public var item: Int
        public var attempt: Int

        public init(step: Int, item: Int, attempt: Int) {
            self.step = step
            self.item = item
            self.attempt = attempt
        }
    }

    public enum Role: Hashable, Sendable {
        /// Count-in at the start or after a change of meter/tempo.
        case countIn
        /// Count-in that follows a response: the verdict of the previous attempt is shown here.
        case leadIn
        case prompt
        case hold
        case response
        /// E10: tap along with the click.
        case withClick
        /// E10: keep tapping the beat in silence.
        case silent
    }

    public struct Measure: Hashable, Sendable {
        public let start: Double
        public let duration: Double
        public let role: Role
        /// The attempt this measure belongs to; for a lead-in, the attempt it leads into (nil at the end).
        public let attemptIndex: Int?
        public var end: Double { start + duration }
    }

    public struct FlowAttempt: Hashable, Sendable {
        public let index: Int
        public let position: Position
        public let step: SessionStep
        public let kind: Kind
        public let item: PlannedItem
        /// The pattern played (E3/E7: the first of the series; E10: one note per macrobeat).
        public let pattern: Pattern
        public let mode: PracticeMode
        public let tempo: Tempo
        public let clickStage: ClickStage
        public let showNotation: Bool
        public let measureDuration: Double
        /// Start of the lead-in measure.
        public let start: Double
        /// End of the attempt's last measure (= start of the next lead-in).
        public let end: Double
        public let prompt: PromptSlot?
        /// Tap attempts (E10: the beats of the silent stretch).
        public let response: ResponseSlot?

        /// A repeat after a miss outside teaching (not graded).
        public var isCorrection: Bool {
            guard position.attempt > 1 else { return false }
            switch step {
            case .echo(let s): return s.mode != .teaching
            case .read(let s): return s.mode != .teaching
            default: return true
            }
        }

        public var question: NameNotationSpec? {
            if case .nameNotation(let q) = step { q } else { nil }
        }
    }

    public private(set) var attempts: [FlowAttempt] = []
    public private(set) var measures: [Measure] = []
    /// Set once nothing more plays in this stream.
    public private(set) var endTime: Double?
    /// Where the next stream starts when this one ends before a fresh-start attempt.
    public private(set) var restartPosition: Position?
    /// The attempt whose outcome decides what comes next.
    public private(set) var awaiting: Int?
    /// The plan so far (grows when the next session is appended).
    public private(set) var steps: [SessionStep]

    private let library: PatternLibrary
    private var sounds: [ScheduledSound] = []

    /// Pickups are at most a third of a measure, so the first half of a lead-in never depends on the outcome.
    static let undecidedFraction = 0.5

    /// `previousMeter`: the meter the learner was just in (a stream restarted after an answer); nil at the
    /// start of a session. A different meter gets the longer count-in.
    public init(steps: [SessionStep], library: PatternLibrary, from position: Position = Position(step: 0, item: 0, attempt: 1),
                previousMeter: Meter? = nil) {
        self.steps = steps
        self.library = library
        guard let first = build(at: position, start: 0, index: 0) else {
            endTime = 0
            return
        }
        let extra = first.attempt.pattern.meter == previousMeter ? 0 : EchoPolicy.newMeterCountInMeasures - 1
        commit(extra > 0 ? build(at: position, start: Double(extra) * first.attempt.measureDuration, index: 0) ?? first : first,
               leadInIsCommitted: false, extraCountIns: extra)
    }

    // MARK: - Reading the stream

    /// Sounds starting in `[from, to)`.
    public func sounds(from: Double, to: Double) -> [ScheduledSound] {
        sounds.filter { $0.time >= from && $0.time < to }
    }

    /// Everything before this time is final.
    public var decidedUntil: Double {
        if let endTime { return endTime }
        guard let last = measures.last else { return 0 }
        return last.start + last.duration * Self.undecidedFraction
    }

    public func measure(at time: Double) -> Measure? {
        measures.last { $0.start <= time && time < $0.end }
    }

    /// The attempt whose verdict belongs in the lead-in measure starting at `time`.
    public func attempt(endingAt time: Double) -> FlowAttempt? {
        attempts.last { abs($0.end - time) < 1e-9 && !$0.kind.isSilent }
    }

    // MARK: - Deciding

    /// Reports the outcome of the awaited attempt and lays out what follows. `more` supplies new steps
    /// when the plan runs out (e.g. the next session); returning none ends the stream after the lead-in.
    public mutating func report(passed: Bool, forAttempt index: Int, more: () -> [SessionStep] = { [] }) {
        guard awaiting == index, let done = attempts.last, done.index == index else { return }
        awaiting = nil
        var next = nextPosition(after: done.position, passed: passed)
        if next == nil {
            let added = more()
            if !added.isEmpty {
                steps += added
                next = nextPosition(after: done.position, passed: passed)
            }
        }
        let leadInEnd = measures.last?.end ?? done.end
        guard let position = next, let candidate = build(at: position, start: measures.last?.start ?? done.end, index: index + 1) else {
            endTime = leadInEnd
            return
        }
        // after an answer the pulse has stopped anyway; a fresh-start attempt needs its own stream
        if done.kind.awaitsInput || candidate.attempt.kind.startsFresh {
            endTime = leadInEnd
            restartPosition = position
            return
        }
        guard let leadIn = measures.last else { return }
        if candidate.attempt.pattern.meter == done.pattern.meter, candidate.attempt.tempo == done.tempo {
            measures[measures.count - 1] = Measure(start: leadIn.start, duration: leadIn.duration, role: .leadIn, attemptIndex: index + 1)
            commit(candidate, leadInIsCommitted: true)
        } else if let probe = build(at: position, start: leadIn.end, index: index + 1) {
            // new meter or tempo: the lead-in stays a verdict measure, then a count-in in the new tempo —
            // longer when the meter itself changes
            let extra = probe.attempt.pattern.meter == done.pattern.meter ? 0 : EchoPolicy.newMeterCountInMeasures - 1
            let moved = extra == 0 ? probe : build(at: position, start: leadIn.end + Double(extra) * probe.attempt.measureDuration, index: index + 1)
            if let moved { commit(moved, leadInIsCommitted: false, extraCountIns: extra) }
        }
    }

    private func nextPosition(after p: Position, passed: Bool) -> Position? {
        guard steps.indices.contains(p.step) else { return nil }
        let step = steps[p.step]
        if !passed, p.attempt < Self.maxTries(step) {
            return Position(step: p.step, item: p.item, attempt: p.attempt + 1)
        }
        if p.item + 1 < Self.itemCount(step) { return Position(step: p.step, item: p.item + 1, attempt: 1) }
        return steps.indices.contains(p.step + 1) ? Position(step: p.step + 1, item: 0, attempt: 1) : nil
    }

    /// Tap exercises repeat a missed pattern right away: teaching until it is right (it is being learned),
    /// otherwise as corrections after the graded first try. Choice questions don't repeat — the answer
    /// has been shown — and neither does the pulse drill, which adapts its length instead.
    static func maxTries(_ step: SessionStep) -> Int {
        switch step {
        case .echo(let s): s.mode == .teaching ? MasteryPolicy.maxTeachingAttempts : MasteryPolicy.maxCorrectionAttempts
        case .read(let s): s.mode == .teaching ? MasteryPolicy.maxTeachingAttempts : MasteryPolicy.maxCorrectionAttempts
        case .answerDifferently: MasteryPolicy.maxCorrectionAttempts
        default: 1
        }
    }

    private static func itemCount(_ step: SessionStep) -> Int {
        switch step {
        case .echo(let s): s.items.count
        case .read(let s): s.items.count
        default: 1
        }
    }

    // MARK: - Building attempts

    private struct Built {
        let attempt: FlowAttempt
        let roles: [Role]
        let sounds: [ScheduledSound]
    }

    /// Lays out the attempt at `position` with its lead-in at `start` (nothing is committed yet).
    private func build(at position: Position, start: Double, index: Int) -> Built? {
        guard steps.indices.contains(position.step) else { return nil }
        let step = steps[position.step]
        let item: PlannedItem, kind: Kind, mode: PracticeMode, tempo: Tempo, stage: ClickStage
        var showNotation = false
        var series: [Pattern] = []
        var gap = EchoPolicy.gapMeasures
        switch step {
        case .echo(let s):
            guard s.items.indices.contains(position.item) else { return nil }
            (item, kind, mode, tempo, stage, showNotation) = (s.items[position.item], .echo, s.mode, s.tempo, s.clickStage, s.showNotation)
            gap = s.gapMeasures
        case .read(let s):
            guard s.items.indices.contains(position.item) else { return nil }
            (item, kind, mode, tempo, stage, showNotation) = (s.items[position.item], s.playsModel ? .readWithModel : .read, s.mode, s.tempo, s.clickStage, true)
        case .nameNotation(let q):
            (item, kind, mode, tempo, stage) = (q.item, .nameNotation, q.mode, q.tempo, .b)
        case .dictation(let d):
            (item, kind, mode, tempo, stage) = (d.item, .dictation, d.mode, d.tempo, .b)
        case .holdPulse(let h):
            guard let meter = library.meters[h.meterID] else { return nil }
            return buildPulse(h, meter: meter, step: step, position: position, start: start, index: index)
        case .whichMeter(let w):
            guard let first = w.series.first else { return nil }
            series = w.series
            (item, kind, mode, tempo, stage) = (PlannedItem(patternID: first.id, unitID: w.unitID, level: w.level, purpose: .review),
                                                .whichMeter, .evaluation, w.tempo, .c)
        case .meterFromNotation(let m):
            guard let first = m.series.first else { return nil }
            return silent(step, kind: .meterFromNotation, pattern: first, unitID: m.unitID, level: .compositeSynthesis,
                          position: position, start: start, index: index)
        case .compose(let c):
            guard let meter = library.meters[c.meterID] else { return nil }
            return silent(step, kind: .compose, pattern: Self.pulsePattern(meter), unitID: c.unitID, level: .improvisationSymbolic,
                          position: position, start: start, index: index)
        case .sameOrDifferent(let d):
            series = [d.first, d.second]
            (item, kind, mode, tempo, stage) = (PlannedItem(generated: d.first, unitID: d.unitID, level: .generalizationAural),
                                                .sameOrDifferent, .evaluation, d.tempo, .c)
        case .answerDifferently(let a):
            (item, kind, mode, tempo, stage) = (PlannedItem(generated: a.prompt, unitID: a.unitID, level: .improvisationAural),
                                                .answerDifferently, .evaluation, a.tempo, .c)
        }
        guard let pattern = series.first ?? item.pattern(in: library) else { return nil }

        let timeline: Timeline
        do {
            timeline = switch kind {
            case .echo: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: stage, gapMeasures: gap)
            case .readWithModel: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: stage)
            case .read: try Timeline.readBlock(patterns: [pattern], tempo: tempo, clickStage: stage)
            case .whichMeter, .sameOrDifferent: try Timeline.listenBlock(patterns: series, tempo: tempo, clickStage: stage)
            case .answerDifferently: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: stage)
            default: try Timeline.listenBlock(patterns: [pattern, pattern], tempo: tempo, clickStage: stage)
            }
        } catch {
            return nil
        }
        let measure = timeline.measureDuration
        // The block's own count-in clicks are replaced by the flow's lead-in; its pickup notes stay.
        let sounds = timeline.sounds.filter { $0.time >= measure || $0.sound == .hiHat }.map { $0.shifted(by: start) }
        let roles: [Role] = timeline.measureRoles.dropFirst().map {
            switch $0 {
            case .countIn: .countIn
            case .prompt: .prompt
            case .hold: .hold
            case .response: .response
            }
        }
        // corrections after a graded try are practice: only the first try counts toward mastery
        let effectiveMode: PracticeMode = mode == .evaluation && position.attempt > 1 ? .practice : mode
        let attempt = FlowAttempt(
            index: index, position: position, step: step, kind: kind, item: item, pattern: pattern, mode: effectiveMode, tempo: tempo,
            clickStage: stage, showNotation: showNotation, measureDuration: measure,
            start: start, end: start + Double(1 + roles.count) * measure,
            prompt: timeline.prompts[0].shifted(by: start), response: timeline.responses.first?.shifted(by: start)
        )
        return Built(attempt: attempt, roles: roles, sounds: sounds)
    }

    /// An attempt with nothing to play (E7, E9 composing): shown at once, the next stream starts afterwards.
    private func silent(_ step: SessionStep, kind: Kind, pattern: Pattern, unitID: String, level: SkillLevel,
                        position: Position, start: Double, index: Int) -> Built {
        let attempt = FlowAttempt(
            index: index, position: position, step: step, kind: kind,
            item: PlannedItem(patternID: pattern.id, unitID: unitID, level: level, purpose: .review),
            pattern: pattern, mode: .evaluation, tempo: .standard(for: pattern.meter), clickStage: .c, showNotation: true,
            measureDuration: 0, start: start, end: start, prompt: nil, response: nil)
        return Built(attempt: attempt, roles: [], sounds: [])
    }

    /// One note per macrobeat: stands in for a pattern where there is none (E10, E9).
    static func pulsePattern(_ meter: Meter) -> Pattern {
        var tick = 0
        let events = meter.macrobeatSpans.map { span -> RhythmEvent in
            defer { tick += span.ticks }
            return RhythmEvent(startTick: tick, ticks: span.ticks, kind: .note, tieToNext: false)
        }
        return Pattern(id: "pulse:\(meter.id)", meter: meter, content: .macroMicro, pickupTicks: 0, events: events)
    }

    /// E10: `| lead-in | with click | silent × n |`; the beats of the silence are the expected taps.
    private func buildPulse(_ h: HoldPulseSpec, meter: Meter, step: SessionStep, position: Position, start: Double, index: Int) -> Built? {
        let measure = h.tempo.seconds(forTicks: meter.measureTicks, in: meter)
        let clicked = PulsePolicy.clickedMeasures
        var sounds: [ScheduledSound] = []
        for k in 0..<clicked {
            sounds += Self.countInClicks(meter, tempo: h.tempo, at: start + Double(1 + k) * measure)
        }
        let silentStart = start + Double(1 + clicked) * measure
        let beats = (0..<h.silentMeasures).flatMap { m in
            meter.macrobeatSpans.map { silentStart + Double(m) * measure + h.tempo.seconds(forTicks: $0.startTick, in: meter) }
        }
        let end = silentStart + Double(h.silentMeasures) * measure
        let firstBeat = h.tempo.seconds(forTicks: meter.macrobeatSpans[0].ticks, in: meter)
        let pulse = Self.pulsePattern(meter)
        let attempt = FlowAttempt(
            index: index, position: position, step: step, kind: .holdPulse,
            item: PlannedItem(patternID: pulse.id, unitID: h.unitID, level: .aural, purpose: .review),
            pattern: pulse, mode: .practice, tempo: h.tempo, clickStage: .c, showNotation: false, measureDuration: measure,
            start: start, end: end, prompt: nil,
            response: ResponseSlot(patternID: pulse.id, start: silentStart - firstBeat / 2, end: end, expectedOnsets: beats,
                                   macrobeatTimes: beats)
        )
        let roles = Array(repeating: Role.withClick, count: clicked) + Array(repeating: Role.silent, count: h.silentMeasures)
        return Built(attempt: attempt, roles: roles, sounds: sounds)
    }

    private mutating func commit(_ b: Built, leadInIsCommitted: Bool, extraCountIns: Int = 0) {
        let attempt = b.attempt
        attempts.append(attempt)
        awaiting = attempt.index
        if attempt.kind.isSilent {
            // nothing to play: the runner shows it at once and starts a new stream afterwards
            endTime = attempt.start
            return
        }
        let measure = attempt.measureDuration
        if !leadInIsCommitted {
            for k in stride(from: extraCountIns, through: 0, by: -1) {
                let start = attempt.start - Double(k) * measure
                measures.append(Measure(start: start, duration: measure, role: .countIn, attemptIndex: attempt.index))
                // E3's count-in gives the macrobeat only, so the microbeats don't reveal the meter
                sounds += Self.countInClicks(attempt.pattern.meter, tempo: attempt.tempo, at: start,
                                             microbeats: attempt.kind != .whichMeter)
            }
        }
        for (k, role) in b.roles.enumerated() {
            measures.append(Measure(start: attempt.start + Double(k + 1) * measure, duration: measure, role: role, attemptIndex: attempt.index))
        }
        sounds += b.sounds
        // The following measure keeps the pulse while the outcome is decided; when the attempt waits for
        // an answer the pulse stops, so it stays silent.
        measures.append(Measure(start: attempt.end, duration: measure, role: .leadIn, attemptIndex: nil))
        if !attempt.kind.awaitsInput {
            sounds += Self.countInClicks(attempt.pattern.meter, tempo: attempt.tempo, at: attempt.end)
        }
    }

    /// Low click on the downbeat, strong on the other macrobeats, weak on microbeats: establishes meter and tempo.
    static func countInClicks(_ meter: Meter, tempo: Tempo, at start: Double, microbeats: Bool = true) -> [ScheduledSound] {
        meter.macrobeatSpans.flatMap { span in
            (0..<span.microbeats).filter { $0 == 0 || microbeats }.map { micro in
                ScheduledSound(time: start + tempo.seconds(forTicks: span.startTick + micro * Rhythm.ticksPerMicrobeat, in: meter),
                               sound: .click(tick: span.startTick + micro * Rhythm.ticksPerMicrobeat, micro: micro))
            }
        }
    }
}

extension ScheduledSound {
    func shifted(by offset: Double) -> ScheduledSound {
        ScheduledSound(time: time + offset, sound: sound, duration: duration)
    }
}

extension PromptSlot {
    func shifted(by offset: Double) -> PromptSlot {
        PromptSlot(patternID: patternID, start: start + offset, end: end + offset,
                   cues: cues.map { SyllableCue(time: $0.time + offset, duration: $0.duration, text: $0.text, kind: $0.kind) })
    }
}

extension ResponseSlot {
    func shifted(by offset: Double) -> ResponseSlot {
        ResponseSlot(patternID: patternID, start: start + offset, end: end + offset,
                     expectedOnsets: expectedOnsets.map { $0 + offset }, macrobeatTimes: macrobeatTimes.map { $0 + offset })
    }
}
