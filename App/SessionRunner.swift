import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Drives one session: `ready → playing → feedback → next` for tap blocks (echo, read),
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

    /// An echo or read step: patterns played/shown in one uninterrupted block, answered by tapping.
    struct TapBlock {
        enum Kind {
            /// By ear, no notation.
            case echo
            /// Notation shown while the pattern plays, then read back (reading, teaching).
            case readWithModel
            /// Notation only (reading, evaluation).
            case read
        }

        let kind: Kind
        let items: [PlannedItem]
        let meterID: String
        let tempo: Tempo
        let clickStage: ClickStage
        let mode: PracticeMode
        let showSyllables: Bool

        var showsNotation: Bool { kind != .echo }
        var exercise: ExerciseKind { kind == .echo ? .echo : .read }
    }

    struct Result: Identifiable {
        let id: Int
        let item: PlannedItem
        let pattern: Pattern
        let grade: OnsetGrade
        let feedback: EchoFeedback
        let tapsFromDownbeat: [Double]
        let syllables: String
        let overlay: StaffRenderer.Overlay
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
    private(set) var results: [Result] = []
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

    var block: TapBlock? {
        switch step {
        case .echo(let s):
            TapBlock(kind: .echo, items: s.items, meterID: s.meterID, tempo: s.tempo, clickStage: s.clickStage,
                     mode: s.mode, showSyllables: s.showSyllables)
        case .read(let s):
            TapBlock(kind: s.playsModel ? .readWithModel : .read, items: s.items, meterID: s.meterID, tempo: s.tempo,
                     clickStage: s.clickStage, mode: s.mode, showSyllables: false)
        default: nil
        }
    }

    var blockMeter: Meter? { block.flatMap { content.library.meters[$0.meterID] } }

    func pattern(_ id: String) -> Pattern? { content.library.pattern(id: id) }

    // MARK: - Tap blocks

    func startBlock() {
        guard let block else { return }
        let patterns = block.items.compactMap { content.library.pattern(id: $0.patternID) }
        do {
            let timeline = switch block.kind {
            case .echo: try Timeline.echoBlock(patterns: patterns, tempo: block.tempo, clickStage: block.clickStage)
            case .readWithModel: try Timeline.echoBlock(patterns: patterns, tempo: block.tempo, clickStage: block.clickStage, gapMeasures: 0)
            case .read: try Timeline.readBlock(patterns: patterns, tempo: block.tempo, clickStage: block.clickStage)
            }
            self.timeline = timeline
            results = []
            phase = .playing
            try recorder.run(timeline, player: content.player, tapSound: true) { [weak self] taps in
                self?.finishBlock(block, patterns: patterns, timeline: timeline, rawTaps: taps)
            }
        } catch {
            self.error = "\(error)"
            phase = .ready
        }
    }

    private func finishBlock(_ block: TapBlock, patterns: [Pattern], timeline: Timeline, rawTaps: [Double]) {
        let compensation = LatencyCompensation(outputLatency: 0, inputOffset: model.inputOffset)
        let taps = rawTaps.map(compensation.blockTime(forRawBlockTime:))
        let deriver = SyllableDeriver()
        results = zip(block.items, zip(patterns, timeline.responses)).enumerated().map { i, entry in
            let (item, (pattern, slot)) = entry
            let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                          responseEnd: slot.end, mode: block.clickStage.timingMode)
            let downbeat = slot.end - timeline.measureDuration
            return Result(
                id: i, item: item, pattern: pattern, grade: grade, feedback: EchoFeedback(grade),
                tapsFromDownbeat: taps.filter { $0 >= slot.start - 0.15 && $0 < slot.end }.map { $0 - downbeat },
                syllables: (try? deriver.line(for: pattern)) ?? "",
                overlay: Self.overlay(grade, pattern: pattern, downbeat: downbeat, tempo: block.tempo)
            )
        }
        for result in results {
            record(Attempt(date: model.now(), unitID: result.item.unitID, level: result.item.level, patternID: result.pattern.id,
                           exercise: block.exercise, mode: block.mode, passed: result.grade.passed, accuracy: result.grade.accuracy))
        }
        phase = .feedback
    }

    /// Expected onsets and taps in measure ticks, taps colored by error.
    private static func overlay(_ grade: OnsetGrade, pattern: Pattern, downbeat: Double, tempo: Tempo) -> StaffRenderer.Overlay {
        let spt = tempo.secondsPerTick(in: pattern.meter)
        func tick(_ t: Double) -> Double { (t - downbeat) / spt }
        let limit = EchoFeedback.earlyLateFraction * grade.tolerance
        let hits = grade.hits.map { (tick: tick($0.tap), mark: abs($0.error) <= limit ? StaffRenderer.Overlay.Mark.good : .off) }
        let extras = grade.extras.map { (tick: tick($0), mark: StaffRenderer.Overlay.Mark.bad) }
        return StaffRenderer.Overlay(expected: pattern.onsets.map { Double($0.startTick) }, taps: hits + extras)
    }

    func replay(_ result: Result) {
        guard let block,
              let t = try? Timeline.replay(pattern: result.pattern, tempo: block.tempo, tapsFromDownbeat: result.tapsFromDownbeat)
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
        case .echo, .read:
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
