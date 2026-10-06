/// The session as one uninterrupted pulse (docs/04-exercises.md §1). Every attempt is
/// `| lead-in | prompt | hold | response |`; the measure right after a response is the next attempt's
/// lead-in, during which the verdict is shown — the click never stops. A change of meter or tempo adds
/// one count-in measure in the new tempo. E2 is `| lead-in | prompt | prompt |`, after which the pulse
/// stops until the learner picks the notation (the stream is restarted from the next attempt).
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
        public let kind: Kind
        public let item: PlannedItem
        public let pattern: Pattern
        public let mode: PracticeMode
        public let tempo: Tempo
        public let clickStage: ClickStage
        public let showNotation: Bool
        public let question: NameNotationSpec?
        public let measureDuration: Double
        /// Start of the lead-in measure.
        public let start: Double
        /// End of the attempt's last measure (= start of the next lead-in).
        public let end: Double
        public let prompt: PromptSlot
        /// Tap attempts only.
        public let response: ResponseSlot?
    }

    public private(set) var attempts: [FlowAttempt] = []
    public private(set) var measures: [Measure] = []
    /// Set once nothing follows: the stream ends here.
    public private(set) var endTime: Double?
    /// The attempt whose outcome decides what comes next.
    public private(set) var awaiting: Int?

    /// The plan so far (grows when the next session is appended).
    public private(set) var steps: [SessionStep]
    private let library: PatternLibrary
    private var sounds: [ScheduledSound] = []

    /// Pickups are at most a third of a measure, so the first half of a lead-in never depends on the outcome.
    static let undecidedFraction = 0.5

    public init(steps: [SessionStep], library: PatternLibrary, from position: Position = Position(step: 0, item: 0, attempt: 1)) {
        self.steps = steps
        self.library = library
        if let first = build(at: position, start: 0, index: 0) {
            commit(first, leadInIsCommitted: false)
        } else {
            endTime = 0
        }
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
        attempts.last { abs($0.end - time) < 1e-9 }
    }

    // MARK: - Deciding

    /// Reports the outcome of the awaited attempt and lays out what follows. `more` supplies new steps
    /// when the plan runs out (e.g. the next session); returning none ends the stream after the lead-in.
    public mutating func report(passed: Bool, forAttempt index: Int, more: () -> [SessionStep] = { [] }) {
        guard awaiting == index, let done = attempts.last, done.index == index, let leadIn = measures.last else { return }
        awaiting = nil
        var next = nextPosition(after: done.position, passed: passed)
        if next == nil {
            let added = more()
            if !added.isEmpty {
                steps += added
                next = nextPosition(after: done.position, passed: passed)
            }
        }
        // The lead-in after `done` already ticks in done's meter and tempo.
        guard let position = next, let candidate = build(at: position, start: leadIn.start, index: index + 1) else {
            endTime = leadIn.end
            return
        }
        if candidate.attempt.pattern.meter == done.pattern.meter, candidate.attempt.tempo == done.tempo {
            measures[measures.count - 1] = Measure(start: leadIn.start, duration: leadIn.duration, role: .leadIn, attemptIndex: index + 1)
            commit(candidate, leadInIsCommitted: true)
        } else if let moved = build(at: position, start: leadIn.end, index: index + 1) {
            // new meter or tempo: the lead-in stays a verdict measure, then a count-in in the new tempo
            commit(moved, leadInIsCommitted: false)
        }
    }

    private func nextPosition(after p: Position, passed: Bool) -> Position? {
        guard steps.indices.contains(p.step) else { return nil }
        let step = steps[p.step]
        if case .echo(let spec) = step, spec.mode == .teaching, !passed, p.attempt < MasteryPolicy.maxTeachingAttempts {
            return Position(step: p.step, item: p.item, attempt: p.attempt + 1)
        }
        if case .read(let spec) = step, spec.mode == .teaching, !passed, p.attempt < MasteryPolicy.maxTeachingAttempts {
            return Position(step: p.step, item: p.item, attempt: p.attempt + 1)
        }
        if p.item + 1 < Self.itemCount(step) { return Position(step: p.step, item: p.item + 1, attempt: 1) }
        return steps.indices.contains(p.step + 1) ? Position(step: p.step + 1, item: 0, attempt: 1) : nil
    }

    private static func itemCount(_ step: SessionStep) -> Int {
        switch step {
        case .echo(let s): s.items.count
        case .read(let s): s.items.count
        case .nameNotation: 1
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
        var question: NameNotationSpec?
        switch step {
        case .echo(let s):
            guard s.items.indices.contains(position.item) else { return nil }
            (item, kind, mode, tempo, stage, showNotation) = (s.items[position.item], .echo, s.mode, s.tempo, s.clickStage, s.showNotation)
        case .read(let s):
            guard s.items.indices.contains(position.item) else { return nil }
            (item, kind, mode, tempo, stage, showNotation) = (s.items[position.item], s.playsModel ? .readWithModel : .read, s.mode, s.tempo, s.clickStage, true)
        case .nameNotation(let q):
            (item, kind, mode, tempo, stage, question) = (q.item, .nameNotation, q.mode, q.tempo, .b, q)
        }
        guard let pattern = library.pattern(id: item.patternID) else { return nil }

        let timeline: Timeline
        do {
            timeline = switch kind {
            case .echo: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: stage)
            case .readWithModel: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: stage, gapMeasures: 0)
            case .read: try Timeline.readBlock(patterns: [pattern], tempo: tempo, clickStage: stage)
            case .nameNotation: try Timeline.listenBlock(patterns: [pattern, pattern], tempo: tempo, clickStage: stage)
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
        let attempt = FlowAttempt(
            index: index, position: position, kind: kind, item: item, pattern: pattern, mode: mode, tempo: tempo,
            clickStage: stage, showNotation: showNotation, question: question, measureDuration: measure,
            start: start, end: start + Double(1 + roles.count) * measure,
            prompt: timeline.prompts[0].shifted(by: start), response: timeline.responses.first?.shifted(by: start)
        )
        return Built(attempt: attempt, roles: roles, sounds: sounds)
    }

    private mutating func commit(_ b: Built, leadInIsCommitted: Bool) {
        let attempt = b.attempt
        let measure = attempt.measureDuration
        if !leadInIsCommitted {
            measures.append(Measure(start: attempt.start, duration: measure, role: .countIn, attemptIndex: attempt.index))
            sounds += Self.countInClicks(attempt.pattern.meter, tempo: attempt.tempo, at: attempt.start)
        }
        for (k, role) in b.roles.enumerated() {
            measures.append(Measure(start: attempt.start + Double(k + 1) * measure, duration: measure, role: role, attemptIndex: attempt.index))
        }
        sounds += b.sounds
        attempts.append(attempt)
        // The following measure keeps the pulse while the outcome is decided; after E2 the pulse stops
        // for the choice, so it stays silent.
        measures.append(Measure(start: attempt.end, duration: measure, role: .leadIn, attemptIndex: nil))
        if attempt.kind != .nameNotation {
            sounds += Self.countInClicks(attempt.pattern.meter, tempo: attempt.tempo, at: attempt.end)
        }
        awaiting = attempt.index
    }

    /// Strong click on macrobeats, weak on microbeats: establishes meter and tempo.
    static func countInClicks(_ meter: Meter, tempo: Tempo, at start: Double) -> [ScheduledSound] {
        meter.macrobeatSpans.flatMap { span in
            (0..<span.microbeats).map { micro in
                ScheduledSound(time: start + tempo.seconds(forTicks: span.startTick + micro * Rhythm.ticksPerMicrobeat, in: meter),
                               sound: .click(accented: micro == 0))
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
