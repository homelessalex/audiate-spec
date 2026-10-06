import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Conducts a session as one uninterrupted pulse (FlowSequencer): attempts follow each other, each
/// verdict shows during the next lead-in measure, and when the plan runs out the next one is planned.
/// E2 ("which notation?") stops the pulse after the two hearings and waits for the choice; the flow then
/// continues from the next attempt with a count-in. Esc pauses; resuming restarts the interrupted attempt.
@MainActor
@Observable
final class SessionRunner {
    enum State: Equatable {
        case running
        /// E2: the pulse has stopped, waiting for the learner to pick the notation.
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

    private(set) var state: State = .paused
    private(set) var flow: FlowSequencer
    private(set) var verdicts: [Int: Verdict] = [:]
    /// E2 answers by attempt index.
    private(set) var choices: [Int: Int] = [:]
    /// The E2 just answered, kept on screen with its result until the flow resumes.
    private(set) var lastAnswer: (question: NameNotationSpec, chosen: Int)?
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

    /// The next batch when the plan runs out: more of today's work, then (in free practice) more practice.
    private func moreSteps() -> [SessionStep] {
        if let next = model.planSession(), !next.isEmpty { return next.steps }
        return isFreePractice ? (model.planFreePractice()?.steps ?? []) : []
    }

    /// From the summary: carry on with free practice.
    func keepPracticing() {
        guard let plan = model.planFreePractice(), !plan.isEmpty else { return }
        isFreePractice = true
        flow = FlowSequencer(steps: plan.steps, library: content.library)
        verdicts = [:]
        choices = [:]
        state = .paused
        start()
    }

    var heardTime: Double? { recorder.heardTime() }

    // MARK: - Running

    func start() {
        guard state != .running else { return }
        do {
            let clock = try content.player.stream(
                provider: { [weak self] from, to in self?.provide(from: from, to: to) },
                onFinish: { [weak self] in self?.finish() }
            )
            recorder.start(clock: clock, player: content.player, tapSound: true)
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
        let heard = state == .choosing ? .infinity : (heardTime ?? 0)
        stopAudio()
        // the attempt in progress (or about to start); an ungraded one is played again
        let current = flow.attempts.first { $0.end > heard }?.index ?? flow.awaiting
        if let current, flow.attempts.indices.contains(current) {
            flow = FlowSequencer(steps: flow.steps, library: content.library, from: flow.attempts[current].position)
        } else {
            flow = FlowSequencer(steps: [], library: content.library)
        }
        verdicts = [:]
        choices = [:]
        state = flow.endTime == 0 ? .finished : .paused
    }

    func end() {
        stopAudio()
        state = .finished
    }

    private func finish() {
        stopAudio()
        state = .finished
    }

    private func stopAudio() {
        ticker?.cancel()
        content.player.stop()
        recorder.stop()
    }

    /// Audio pulls sounds ~0.3 s ahead; anything past `decidedUntil` needs the pending outcome first.
    private func provide(from: Double, to: Double) -> [ScheduledSound]? {
        if let index = flow.awaiting, flow.attempts[index].question == nil, to > flow.decidedUntil { gradeAwaiting() }
        if let end = flow.endTime, from >= end { return nil }
        return flow.sounds(from: from, to: to)
    }

    private func gradeIfDue() {
        guard state == .running, let index = flow.awaiting, let heard = heardTime, heard >= flow.attempts[index].end else { return }
        if flow.attempts[index].question != nil {
            // E2: stop the pulse and let the learner choose without a clock
            stopAudio()
            state = .choosing
        } else {
            gradeAwaiting()
        }
    }

    /// The E2 question waiting for a choice.
    var pendingQuestion: (attempt: FlowSequencer.FlowAttempt, question: NameNotationSpec)? {
        guard let index = flow.awaiting, let q = flow.attempts[index].question else { return nil }
        return (flow.attempts[index], q)
    }

    // MARK: - Grading

    private func gradeAwaiting() {
        guard let index = flow.awaiting else { return }
        let attempt = flow.attempts[index]
        let passed: Bool
        if let question = attempt.question {
            passed = choices[index] == question.correctIndex
            verdicts[index] = Verdict(passed: passed, reasons: [], comparison: nil)
            record(attempt, exercise: .nameNotation, passed: passed, accuracy: passed ? 1 : 0)
        } else if let slot = attempt.response {
            let taps = recorder.taps.map { $0 - model.inputOffset }
            let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                          responseEnd: slot.end, mode: attempt.clickStage.timingMode)
            passed = grade.passed
            let reading = attempt.kind == .read || attempt.kind == .readWithModel
            verdicts[index] = Verdict(
                passed: passed, reasons: grade.errors.map(Self.describe),
                comparison: reading ? Self.comparison(grade, pattern: attempt.pattern, downbeat: slot.end - attempt.measureDuration,
                                                      tempo: attempt.tempo) : nil
            )
            record(attempt, exercise: reading ? .read : .echo, passed: passed, accuracy: grade.accuracy)
        } else {
            passed = false
        }
        flow.report(passed: passed, forAttempt: index) { [weak self] in self?.moreSteps() ?? [] }
    }

    /// E2 choice: show it for a moment, then continue the flow from the next attempt.
    func choose(_ option: Int) {
        guard state == .choosing, let index = flow.awaiting, flow.attempts[index].question != nil, choices[index] == nil else { return }
        choices[index] = option
        if let question = flow.attempts[index].question { lastAnswer = (question, option) }
        gradeAwaiting()
        // a wrong answer stays longer so the right notation can be studied
        let pause = option == flow.attempts[index].question?.correctIndex ? MasteryPolicy.verdictSeconds : Self.wrongAnswerSeconds
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(pause))
            self?.continueAfterChoice(index)
        }
    }

    private func continueAfterChoice(_ index: Int) {
        guard state == .choosing else { return }
        guard flow.attempts.indices.contains(index + 1) else {
            state = .finished
            return
        }
        flow = FlowSequencer(steps: flow.steps, library: content.library, from: flow.attempts[index + 1].position)
        verdicts = [:]
        choices = [:]
        lastAnswer = nil
        state = .paused
        start()
    }

    private func record(_ attempt: FlowSequencer.FlowAttempt, exercise: ExerciseKind, passed: Bool, accuracy: Double) {
        newlyPassed += model.record(Attempt(date: model.now(), unitID: attempt.item.unitID, level: attempt.item.level,
                                            patternID: attempt.pattern.id, exercise: exercise, mode: attempt.mode,
                                            passed: passed, accuracy: accuracy))
    }

    static let wrongAnswerSeconds = 2.5

    static func describe(_ error: AttemptError) -> String {
        switch error {
        case .missedBeat: "Missed a beat"
        case .extraTap: "Extra tap"
        case .timingOff: "Timing off"
        }
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
