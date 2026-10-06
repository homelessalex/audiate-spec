import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Conducts a session as one uninterrupted pulse (FlowSequencer): attempts follow each other, each
/// verdict shows during the next lead-in measure, and when the plan runs out the next one is planned.
/// Answer exercises (E2 which notation, E3 which meter, E6 dictation, E7 meter from notation) stop the
/// pulse and wait without a clock; the flow then continues with a count-in. Esc pauses; resuming restarts
/// the interrupted attempt.
@MainActor
@Observable
final class SessionRunner {
    enum State: Equatable {
        case running
        /// The pulse has stopped, waiting for an answer.
        case choosing
        case paused
        case finished
    }

    struct Verdict {
        let passed: Bool
        let reasons: [String]
        /// Reading only (from SA): notes vs. taps on the staff.
        let comparison: StaffRenderer.Comparison?
    }

    /// An answered question, kept on screen with its result until the flow resumes.
    struct Answer {
        let attempt: FlowSequencer.FlowAttempt
        let choice: Int?
        let written: [Cell?]?
        let passed: Bool
    }

    private(set) var state: State = .paused
    private(set) var flow: FlowSequencer
    private(set) var verdicts: [Int: Verdict] = [:]
    private(set) var lastAnswer: Answer?
    private(set) var newlyPassed: [LevelKey] = []
    /// After the day's work: endless practice of taught patterns, not counted.
    private(set) var isFreePractice: Bool
    private(set) var error: String?
    let recorder = TapRecorder()

    private let content: AppModel.Content
    private unowned let model: AppModel
    private var ticker: Task<Void, Never>?

    init(plan: SessionPlan, content: AppModel.Content, model: AppModel, freePractice: Bool = false) {
        self.content = content
        self.model = model
        isFreePractice = freePractice
        flow = FlowSequencer(steps: plan.steps, library: content.library)
    }

    var heardTime: Double? { recorder.heardTime() }
    var twoHandMode: Bool { model.settings.twoHandMode }
    var library: PatternLibrary { content.library }

    /// The next batch when the plan runs out: more of today's work, then (in free practice) more practice.
    private func moreSteps() -> [SessionStep] {
        if let next = model.planSession(), !next.isEmpty { return next.steps }
        return isFreePractice ? (model.planFreePractice()?.steps ?? []) : []
    }

    /// From the summary: carry on with free practice.
    func keepPracticing() {
        guard let plan = model.planFreePractice(), !plan.isEmpty else { return }
        isFreePractice = true
        restart(FlowSequencer(steps: plan.steps, library: content.library))
    }

    // MARK: - Running

    func start() {
        guard state != .running else { return }
        // E7 has nothing to play: show it straight away
        if let index = flow.awaiting, flow.attempts[index].kind.isSilent {
            state = .choosing
            return
        }
        do {
            let clock = try content.player.stream(
                provider: { [weak self] from, to in self?.provide(from: from, to: to) },
                onFinish: { [weak self] in self?.streamEnded() }
            )
            recorder.start(clock: clock, player: content.player, tapSound: model.settings.tapSound)
            state = .running
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    self?.gradeIfDue()
                    try? await Task.sleep(for: .milliseconds(30))
                }
            }
        } catch {
            self.error = "\(error)"
        }
    }

    /// Esc: stop the pulse; the attempt in progress is dropped and starts again on resume.
    func pause() {
        guard state == .running || state == .choosing else { return }
        if let answered = lastAnswer {
            // the answer is done: pause before whatever comes next
            stopAudio()
            let index = answered.attempt.index
            let next = flow.attempts.indices.contains(index + 1) ? flow.attempts[index + 1].position : flow.restartPosition
            guard let next else { state = .finished; return }
            flow = FlowSequencer(steps: flow.steps, library: content.library, from: next)
            verdicts = [:]
            lastAnswer = nil
            state = .paused
            return
        }
        let heard = state == .choosing ? .infinity : (heardTime ?? 0)
        stopAudio()
        // the attempt in progress (or about to start); an ungraded one is played again
        let current = flow.attempts.first { $0.end > heard }?.index ?? flow.awaiting
        if let current, flow.attempts.indices.contains(current) {
            flow = FlowSequencer(steps: flow.steps, library: content.library, from: flow.attempts[current].position)
            verdicts = [:]
            lastAnswer = nil
            state = .paused
        } else {
            state = .finished
        }
    }

    func end() {
        stopAudio()
        state = .finished
    }

    /// The stream ran out: either the plan is done, or a fresh-start attempt (E3, E7) follows.
    private func streamEnded() {
        stopAudio()
        if let position = flow.restartPosition {
            restart(FlowSequencer(steps: flow.steps, library: content.library, from: position))
        } else {
            state = .finished
        }
    }

    private func restart(_ next: FlowSequencer) {
        flow = next
        verdicts = [:]
        lastAnswer = nil
        state = .paused
        if flow.endTime == 0, flow.awaiting == nil {
            state = .finished
        } else {
            start()
        }
    }

    private func stopAudio() {
        ticker?.cancel()
        content.player.stop()
        recorder.stop()
    }

    /// Audio pulls sounds ~0.3 s ahead; anything past `decidedUntil` needs the pending outcome first.
    private func provide(from: Double, to: Double) -> [ScheduledSound]? {
        if let index = flow.awaiting, !flow.attempts[index].kind.awaitsInput, to > flow.decidedUntil { gradeAwaiting() }
        if let end = flow.endTime, from >= end { return nil }
        return flow.sounds(from: from, to: to)
    }

    private func gradeIfDue() {
        guard state == .running, let index = flow.awaiting, let heard = heardTime, heard >= flow.attempts[index].end else { return }
        if flow.attempts[index].kind.awaitsInput {
            // stop the pulse and let the learner answer without a clock
            stopAudio()
            state = .choosing
        } else {
            gradeAwaiting()
        }
    }

    /// The attempt waiting for an answer.
    var pendingAnswer: FlowSequencer.FlowAttempt? {
        guard state == .choosing, lastAnswer == nil, let index = flow.awaiting else { return nil }
        return flow.attempts[index]
    }

    // MARK: - Grading tap attempts

    private func gradeAwaiting() {
        guard let index = flow.awaiting, let slot = flow.attempts[index].response else { return }
        let attempt = flow.attempts[index]
        let taps = recorder.taps.map { $0 - model.inputOffset }
        let passed: Bool
        if case .answerDifferently(let spec) = attempt.step {
            let grade = ImprovGrader.grade(taps: taps, prompt: spec.prompt, downbeat: slot.end - attempt.measureDuration,
                                           tempo: attempt.tempo, unlocked: spec.unlocked)
            passed = grade.passed
            verdicts[index] = Verdict(passed: passed, reasons: grade.problems.map(Self.describe), comparison: nil)
            record(attempt, exercise: .answerDifferently, patternID: nil, passed: passed, accuracy: passed ? 1 : 0)
        } else if attempt.kind == .holdPulse {
            // either hand may keep the beat here
            let grade = PulseGrader.grade(beats: slot.expectedOnsets, taps: taps + recorder.pulseTaps.map { $0 - model.inputOffset })
            passed = grade.passed
            verdicts[index] = Verdict(passed: passed, reasons: Self.describe(grade), comparison: nil)
            record(attempt, exercise: .holdThePulse, patternID: nil, passed: passed, accuracy: passed ? 1 : 0)
        } else {
            let mode = attempt.clickStage.timingMode
            let twoHands = model.settings.twoHandMode
                ? TwoHandGrade.grade(slot: slot, rhythmTaps: taps, pulseTaps: recorder.pulseTaps.map { $0 - model.inputOffset }, mode: mode)
                : nil
            let grade = twoHands?.rhythm ?? OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                                              responseEnd: slot.end, mode: mode)
            passed = twoHands?.passed ?? grade.passed
            var reasons = grade.errors.map(Self.describe)
            if let twoHands {
                reasons = reasons.map { "Right hand: " + $0.lowercased() } + twoHands.pulse.errors.map { "Left hand: " + Self.describe($0).lowercased() }
            }
            let reading = attempt.kind == .read || attempt.kind == .readWithModel
            verdicts[index] = Verdict(
                passed: passed, reasons: reasons,
                comparison: reading ? Self.comparison(grade, pattern: attempt.pattern, downbeat: slot.end - attempt.measureDuration,
                                                      tempo: attempt.tempo) : nil
            )
            var exercise: ExerciseKind = reading ? .read : .echo
            if case .echo(let spec) = attempt.step { exercise = spec.exercise }
            if attempt.item.level == .improvisationSymbolic { exercise = .composeAndPerform }
            record(attempt, exercise: exercise, patternID: Self.patternID(attempt), passed: passed,
                   accuracy: twoHands?.accuracy ?? grade.accuracy)
        }
        flow.report(passed: passed, forAttempt: index) { [weak self] in self?.moreSteps() ?? [] }
    }

    // MARK: - Answers

    /// E2, E3, E7: pick an option.
    func choose(_ option: Int) {
        guard let attempt = pendingAnswer else { return }
        let passed: Bool, exercise: ExerciseKind, patternID: String?
        switch attempt.step {
        case .nameNotation(let q): (passed, exercise, patternID) = (option == q.correctIndex, .nameNotation, Self.patternID(attempt))
        case .sameOrDifferent(let d): (passed, exercise, patternID) = ((option == 0) == d.isSame, .sameOrDifferent, nil)
        case .whichMeter(let w): (passed, exercise, patternID) = (option == w.correctIndex, .whichMeter, nil)
        case .meterFromNotation(let m): (passed, exercise, patternID) = (option == m.correctIndex, .meterFromNotation, nil)
        default: return
        }
        answer(attempt, Answer(attempt: attempt, choice: option, written: nil, passed: passed), exercise: exercise, patternID: patternID)
    }

    /// E6: the cells written, one per macrobeat.
    func submit(dictation written: [Cell?]) {
        guard let attempt = pendingAnswer, case .dictation(let d) = attempt.step else { return }
        let passed = Dictation.firstDifference(answer: d.answer, written: written) == nil
        answer(attempt, Answer(attempt: attempt, choice: nil, written: written, passed: passed), exercise: .write,
               patternID: Self.patternID(attempt))
    }

    /// E9: the learner's own pattern; next they perform it from the notation (graded as E9).
    func submit(composition cells: [Cell]) {
        guard let attempt = pendingAnswer, case .compose(let spec) = attempt.step,
              let meter = content.library.meters[spec.meterID],
              let composed = Dictation.pattern(from: cells, meter: meter, id: "composed") else { return }
        let perform = SessionStep.read(ReadBlockSpec(
            items: [PlannedItem(generated: composed, unitID: spec.unitID, level: .improvisationSymbolic)],
            meterID: meter.id, tempo: spec.tempo, clickStage: .c, mode: .evaluation))
        var steps = flow.steps
        let at = attempt.position.step + 1
        steps.insert(perform, at: min(at, steps.count))
        restart(FlowSequencer(steps: steps, library: content.library, from: .init(step: at, item: 0, attempt: 1)))
    }

    /// Library patterns are graded per pattern; generated ones per unit (nil).
    private static func patternID(_ attempt: FlowSequencer.FlowAttempt) -> String? {
        attempt.item.generated == nil ? attempt.pattern.id : nil
    }

    private func answer(_ attempt: FlowSequencer.FlowAttempt, _ result: Answer, exercise: ExerciseKind, patternID: String?) {
        lastAnswer = result
        record(attempt, exercise: exercise, patternID: patternID, passed: result.passed, accuracy: result.passed ? 1 : 0)
        flow.report(passed: result.passed, forAttempt: attempt.index) { [weak self] in self?.moreSteps() ?? [] }
        // a wrong answer stays longer so the right one can be studied; dictation waits for Return
        guard attempt.kind != .dictation else { return }
        let pause = result.passed ? MasteryPolicy.verdictSeconds : Self.wrongAnswerSeconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(pause))
            self?.continueAfterAnswer()
        }
    }

    /// After an answer: the next attempt starts a new stream with a count-in.
    func continueAfterAnswer() {
        guard state == .choosing, let answered = lastAnswer else { return }
        let index = answered.attempt.index
        if flow.attempts.indices.contains(index + 1) {
            restart(FlowSequencer(steps: flow.steps, library: content.library, from: flow.attempts[index + 1].position))
        } else if let position = flow.restartPosition {
            restart(FlowSequencer(steps: flow.steps, library: content.library, from: position))
        } else {
            state = .finished
        }
    }

    private func record(_ attempt: FlowSequencer.FlowAttempt, exercise: ExerciseKind, patternID: String?, passed: Bool, accuracy: Double) {
        newlyPassed += model.record(Attempt(date: model.now(), unitID: attempt.item.unitID, level: attempt.item.level,
                                            patternID: patternID, exercise: exercise, mode: attempt.mode,
                                            passed: passed, accuracy: accuracy))
    }

    // MARK: - Wording

    static let wrongAnswerSeconds = 2.5

    static func describe(_ error: AttemptError) -> String {
        switch error {
        case .missedBeat: "Missed a beat"
        case .extraTap: "Extra tap"
        case .timingOff: "Timing off"
        }
    }

    static func describe(_ problem: ImprovGrade.Problem) -> String {
        switch problem {
        case .sameAsPrompt: "That was the same pattern — answer with a different one"
        case .offGrid: "Off the grid"
        case .tooFew: "Too few notes"
        case .tempoDrift: "Tempo drifted"
        }
    }

    static func describe(_ grade: PulseGrade) -> [String] {
        var lines: [String] = []
        if grade.problems.contains(.lostCount) { lines.append("Lost count: \(grade.taps) taps for \(grade.beats) beats") }
        if grade.problems.contains(.drifted) {
            lines.append(String(format: "Ended %.0f %% of a beat %@", abs(grade.drift) * 100, grade.drift > 0 ? "late (slowed down)" : "early (rushed)"))
        }
        if grade.problems.contains(.uneven) { lines.append("Uneven beats") }
        if grade.passed { lines.append(String(format: "Ended %+.0f %% of a beat", grade.drift * 100)) }
        return lines
    }

    static func meterName(_ meter: Meter) -> String {
        if meter.isUnusual { return "\(meter.timeSignature) · " + meter.macrobeats.map(String.init).joined(separator: "+") }
        if meter.allowsThirds { return "Duple with triplets · \(meter.timeSignature)" }
        return (meter.macrobeats.first == 3 ? "Triple · " : "Duple · ") + meter.timeSignature.description
    }

    /// "Pattern vs. you" in measure ticks, for reading (from SA).
    static func comparison(_ grade: OnsetGrade, pattern: Pattern, downbeat: Double, tempo: Tempo) -> StaffRenderer.Comparison {
        let spt = tempo.secondsPerTick(in: pattern.meter)
        func tick(_ t: Double) -> Double { (t - downbeat) / spt }
        let limit = EchoFeedback.earlyLateFraction * grade.tolerance
        var notes: [(start: Double, end: Double)] = []
        for event in pattern.events {
            switch event.kind {
            case .note: notes.append((Double(event.startTick), Double(event.endTick)))
            case .continuation: if let last = notes.popLast() { notes.append((last.start, Double(event.endTick))) }
            case .rest: break
            }
        }
        return StaffRenderer.Comparison(
            notes: notes,
            hits: grade.hits.map {
                .init(expected: tick($0.expected).rounded(), tap: tick($0.tap), errorMs: Int(($0.error * 1000).rounded()),
                      mark: abs($0.error) <= limit ? .good : .off)
            },
            misses: grade.misses.map { tick($0).rounded() },
            extras: grade.extras.map(tick)
        )
    }
}
