import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Conducts a session as one uninterrupted pulse (FlowSequencer): attempts follow each other, each
/// verdict shows during the next lead-in measure, and when the plan runs out the next one is planned.
/// Esc pauses (the pulse stops); resuming starts the interrupted attempt again with a count-in.
@MainActor
@Observable
final class SessionRunner {
    enum State: Equatable {
        case running
        case paused
        case finished
    }

    struct Verdict {
        let passed: Bool
        let reasons: [String]
        /// Reading only (from SA): notes vs. taps on the staff.
        let comparison: StaffRenderer.Comparison?
        /// E2: the right syllables, shown after the answer.
        let answer: String?
    }

    private(set) var state: State = .paused
    private(set) var flow: FlowSequencer
    private(set) var verdicts: [Int: Verdict] = [:]
    /// E2 answers by attempt index.
    private(set) var choices: [Int: Int] = [:]
    private(set) var newlyPassed: [LevelKey] = []
    private(set) var error: String?
    let recorder = TapRecorder()

    private let content: AppModel.Content
    private unowned let model: AppModel
    private var ticker: Task<Void, Never>?

    init(plan: SessionPlan, content: AppModel.Content, model: AppModel) {
        self.content = content
        self.model = model
        flow = FlowSequencer(steps: plan.steps, library: content.library)
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
        guard state == .running else { return }
        let heard = heardTime ?? 0
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
        if flow.awaiting != nil, to > flow.decidedUntil { gradeAwaiting() }
        if let end = flow.endTime, from >= end { return nil }
        return flow.sounds(from: from, to: to)
    }

    private func gradeIfDue() {
        guard let index = flow.awaiting, let heard = heardTime, heard >= flow.attempts[index].end else { return }
        gradeAwaiting()
    }

    // MARK: - Grading

    private func gradeAwaiting() {
        guard let index = flow.awaiting else { return }
        let attempt = flow.attempts[index]
        let passed: Bool
        if let question = attempt.question {
            let choice = choices[index]
            passed = choice == question.correctIndex
            verdicts[index] = Verdict(passed: passed, reasons: passed ? [] : [choice == nil ? "No answer" : "Wrong syllables"],
                                      comparison: nil, answer: question.options[question.correctIndex])
            record(attempt, exercise: .nameSyllables, passed: passed, accuracy: passed ? 1 : 0)
        } else if let slot = attempt.response {
            let taps = recorder.taps.map { $0 - model.inputOffset }
            let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                          responseEnd: slot.end, mode: attempt.clickStage.timingMode)
            passed = grade.passed
            let reading = attempt.kind == .read || attempt.kind == .readWithModel
            verdicts[index] = Verdict(
                passed: passed, reasons: grade.errors.map(Self.describe),
                comparison: reading ? Self.comparison(grade, pattern: attempt.pattern, downbeat: slot.end - attempt.measureDuration,
                                                      tempo: attempt.tempo) : nil,
                answer: nil
            )
            record(attempt, exercise: reading ? .read : .echo, passed: passed, accuracy: grade.accuracy)
        } else {
            passed = false
        }
        flow.report(passed: passed, forAttempt: index) { [weak self] in self?.model.planSession()?.steps ?? [] }
    }

    func choose(_ option: Int) {
        guard let index = flow.awaiting, flow.attempts[index].question != nil, choices[index] == nil,
              let heard = heardTime, heard >= flow.attempts[index].prompt.start else { return }
        choices[index] = option
    }

    private func record(_ attempt: FlowSequencer.FlowAttempt, exercise: ExerciseKind, passed: Bool, accuracy: Double) {
        newlyPassed += model.record(Attempt(date: model.now(), unitID: attempt.item.unitID, level: attempt.item.level,
                                            patternID: attempt.pattern.id, exercise: exercise, mode: attempt.mode,
                                            passed: passed, accuracy: accuracy))
    }

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
