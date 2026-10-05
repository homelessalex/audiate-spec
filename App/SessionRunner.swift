import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Drives one session: `ready → playing → feedback → next` for echo blocks,
/// `question → answered → next` for E2, then `summary`. Audio callbacks reach it on the main actor.
@MainActor
@Observable
final class SessionRunner {
    enum Phase: Equatable {
        case ready
        case playing
        case feedback
        case question
        case summary
    }

    struct EchoResult: Identifiable {
        let id: Int
        let item: PlannedItem
        let pattern: Pattern
        let grade: OnsetGrade
        let feedback: EchoFeedback
        let tapsFromDownbeat: [Double]
        let syllables: String
    }

    struct Question {
        let spec: NameSyllablesSpec
        var plays = 0
        var chosen: Int?
    }

    let plan: SessionPlan
    let recorder = TapRecorder()
    private(set) var stepIndex = 0
    private(set) var phase: Phase = .ready
    private(set) var timeline: Timeline?
    private(set) var results: [EchoResult] = []
    private(set) var question: Question?
    private(set) var newlyPassed: [LevelKey] = []
    private(set) var error: String?

    private let content: AppModel.Content
    private unowned let model: AppModel

    init(plan: SessionPlan, content: AppModel.Content, model: AppModel) {
        self.plan = plan
        self.content = content
        self.model = model
        enterStep()
    }

    var step: SessionStep? { plan.steps.indices.contains(stepIndex) ? plan.steps[stepIndex] : nil }

    var echoSpec: EchoBlockSpec? {
        if case .echo(let spec) = step { spec } else { nil }
    }

    var echoMeter: Meter? { echoSpec.flatMap { content.library.meters[$0.meterID] } }

    // MARK: - Echo

    func startEcho() {
        guard let spec = echoSpec else { return }
        let patterns = spec.items.compactMap { content.library.pattern(id: $0.patternID) }
        do {
            let timeline = try Timeline.echoBlock(patterns: patterns, tempo: spec.tempo, clickStage: spec.clickStage)
            self.timeline = timeline
            results = []
            phase = .playing
            try recorder.run(timeline, player: content.player, tapSound: true) { [weak self] taps in
                self?.finishEcho(spec: spec, patterns: patterns, timeline: timeline, rawTaps: taps)
            }
        } catch {
            self.error = "\(error)"
            phase = .ready
        }
    }

    private func finishEcho(spec: EchoBlockSpec, patterns: [Pattern], timeline: Timeline, rawTaps: [Double]) {
        let compensation = LatencyCompensation(outputLatency: 0, inputOffset: model.inputOffset)
        let taps = rawTaps.map(compensation.blockTime(forRawBlockTime:))
        let deriver = SyllableDeriver()
        results = zip(spec.items, zip(patterns, timeline.responses)).enumerated().map { i, entry in
            let (item, (pattern, slot)) = entry
            let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                          responseEnd: slot.end, mode: spec.clickStage.timingMode)
            let downbeat = slot.end - timeline.measureDuration
            return EchoResult(
                id: i, item: item, pattern: pattern, grade: grade, feedback: EchoFeedback(grade),
                tapsFromDownbeat: taps.filter { $0 >= slot.start - 0.15 && $0 < slot.end }.map { $0 - downbeat },
                syllables: (try? deriver.line(for: pattern)) ?? ""
            )
        }
        for result in results {
            record(Attempt(date: model.now(), unitID: result.item.unitID, level: result.item.level, patternID: result.pattern.id,
                           exercise: .echo, mode: spec.mode, passed: result.grade.passed, accuracy: result.grade.accuracy))
        }
        phase = .feedback
    }

    func replay(_ result: EchoResult) {
        guard let spec = echoSpec,
              let t = try? Timeline.replay(pattern: result.pattern, tempo: spec.tempo, tapsFromDownbeat: result.tapsFromDownbeat)
        else { return }
        _ = try? content.player.play(t) {}
    }

    // MARK: - Name the syllables

    func playQuestion() {
        guard var q = question, q.chosen == nil, q.plays <= q.spec.replays,
              let pattern = content.library.pattern(id: q.spec.item.patternID),
              let t = try? Timeline.listenBlock(patterns: [pattern], tempo: q.spec.tempo, clickStage: .b) else { return }
        q.plays += 1
        question = q
        _ = try? content.player.play(t) {}
    }

    var canReplayQuestion: Bool {
        guard let q = question else { return false }
        return q.chosen == nil && q.plays <= q.spec.replays
    }

    func choose(_ index: Int) {
        guard var q = question, q.chosen == nil, q.spec.options.indices.contains(index) else { return }
        q.chosen = index
        question = q
        content.player.stop()
        let passed = index == q.spec.correctIndex
        record(Attempt(date: model.now(), unitID: q.spec.item.unitID, level: q.spec.item.level, patternID: q.spec.item.patternID,
                       exercise: .nameSyllables, mode: q.spec.mode, passed: passed, accuracy: passed ? 1 : 0))
    }

    // MARK: - Flow

    func next() {
        content.player.stop()
        stepIndex += 1
        enterStep()
    }

    /// Esc: stop the block; the step can be started again (nothing is recorded for it).
    func pause() {
        content.player.stop()
        recorder.cancel()
        if phase == .playing { phase = .ready }
    }

    private func enterStep() {
        timeline = nil
        results = []
        question = nil
        switch step {
        case .echo:
            phase = .ready
        case .nameSyllables(let spec):
            question = Question(spec: spec)
            phase = .question
        case nil:
            phase = .summary
        }
    }

    private func record(_ attempt: Attempt) {
        newlyPassed += model.record(attempt)
    }
}
