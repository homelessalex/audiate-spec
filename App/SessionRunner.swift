import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Drives one session. Tap steps (echo, read) go pattern by pattern: each attempt is a short block with its
/// own count-in (`playing`), followed at once by a yes/no `verdict`. Teaching repeats a pattern until it
/// is correct (at most MasteryPolicy.maxTeachingAttempts); evaluation gives one attempt.
/// E2 runs as `question`; the session ends in `summary`. Audio callbacks reach it on the main actor.
@MainActor
@Observable
final class SessionRunner {
    enum Phase: Equatable {
        case ready
        case playing
        case verdict
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
        /// Shown only for reading (from SA); ear steps give yes/no.
        let comparison: StaffRenderer.Comparison
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
    /// Pattern being practiced within the current tap step, and its attempt number (1-based).
    private(set) var itemIndex = 0
    private(set) var attempt = 1
    private(set) var lastResult: Result?
    /// Tempo of the attempt being played (teaching slows down after a miss).
    private(set) var currentTempo: Tempo?
    private var advanceTask: Task<Void, Never>?
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

    /// Return on the ready screen: starts (or resumes) the step at the current pattern.
    func startBlock() {
        playAttempt()
    }

    var progressLabel: String {
        guard let block else { return "" }
        var s = "Pattern \(itemIndex + 1) of \(block.items.count)"
        if block.mode == .teaching { s += " · try \(attempt) of \(MasteryPolicy.maxTeachingAttempts)" }
        if let tempo = currentTempo, let meter = blockMeter {
            s += " · \(Int(tempo.bpm.rounded())) \(meter.isUnusual ? "eighths/min" : "BPM")"
        }
        return s
    }

    var currentItem: PlannedItem? {
        block.flatMap { $0.items.indices.contains(itemIndex) ? $0.items[itemIndex] : nil }
    }

    private func playAttempt() {
        guard let block, let item = currentItem, let pattern = content.library.pattern(id: item.patternID) else { return }
        let tempo = block.mode == .teaching ? TempoPolicy.teaching(for: pattern.meter, attempt: attempt) : block.tempo
        currentTempo = tempo
        do {
            let timeline = switch block.kind {
            case .echo: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: block.clickStage)
            case .readWithModel: try Timeline.echoBlock(patterns: [pattern], tempo: tempo, clickStage: block.clickStage, gapMeasures: 0)
            case .read: try Timeline.readBlock(patterns: [pattern], tempo: tempo, clickStage: block.clickStage)
            }
            self.timeline = timeline
            lastResult = nil
            phase = .playing
            try recorder.run(timeline, player: content.player, tapSound: true) { [weak self] taps in
                self?.finishAttempt(block, item: item, pattern: pattern, tempo: tempo, timeline: timeline, rawTaps: taps)
            }
        } catch {
            self.error = "\(error)"
            phase = .ready
        }
    }

    private func finishAttempt(_ block: TapBlock, item: PlannedItem, pattern: Pattern, tempo: Tempo, timeline: Timeline, rawTaps: [Double]) {
        guard let slot = timeline.responses.first else { return }
        let compensation = LatencyCompensation(outputLatency: 0, inputOffset: model.inputOffset)
        let taps = rawTaps.map(compensation.blockTime(forRawBlockTime:))
        let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps, responseStart: slot.start,
                                      responseEnd: slot.end, mode: block.clickStage.timingMode)
        let downbeat = slot.end - timeline.measureDuration
        lastResult = Result(id: itemIndex, item: item, pattern: pattern, grade: grade,
                            comparison: Self.comparison(grade, pattern: pattern, downbeat: downbeat, tempo: tempo))
        record(Attempt(date: model.now(), unitID: item.unitID, level: item.level, patternID: pattern.id,
                       exercise: block.exercise, mode: block.mode, passed: grade.passed, accuracy: grade.accuracy))
        phase = .verdict
        // Ear steps: yes/no only, then straight on. Reading (from SA) waits for Return so the comparison can be read.
        guard !block.showsNotation else { return }
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(MasteryPolicy.verdictSeconds))
            guard !Task.isCancelled else { return }
            self?.advance()
        }
    }

    /// Will the current pattern be tried again after this verdict?
    var willRetry: Bool {
        guard let block, let result = lastResult else { return false }
        return block.mode == .teaching && !result.grade.passed && attempt < MasteryPolicy.maxTeachingAttempts
    }

    /// After a verdict: retry the pattern, go to the next one, or finish the step.
    func advance() {
        advanceTask?.cancel()
        guard phase == .verdict else { return }
        if stepForward() { playAttempt() } else { next() }
    }

    /// Moves to the next attempt; false when the step is done.
    private func stepForward() -> Bool {
        guard let block else { return false }
        if willRetry {
            attempt += 1
        } else {
            itemIndex += 1
            attempt = 1
        }
        return itemIndex < block.items.count
    }

    /// "Pattern vs. you" in measure ticks: note spans, hits joined to their notes, misses, extras.
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

    /// Live taps for response `index`, in that measure's ticks (display only).
    func liveTaps(responseIndex index: Int) -> [Double] {
        guard let timeline, let block, timeline.responses.indices.contains(index),
              let meter = content.library.meters[block.meterID] else { return [] }
        let slot = timeline.responses[index]
        let downbeat = slot.end - timeline.measureDuration
        let offset = model.inputOffset
        let spt = (currentTempo ?? block.tempo).secondsPerTick(in: meter)
        return recorder.taps.map { $0 - offset }.filter { $0 >= slot.start - 0.15 && $0 < slot.end }.map { ($0 - downbeat) / spt }
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

    /// Esc: stop; the step resumes at the same pattern and attempt (nothing is recorded for the interrupted one).
    func pause() {
        advanceTask?.cancel()
        content.player.stop()
        recorder.cancel()
        if phase == .verdict, !stepForward() {
            next()
            return
        }
        if phase == .playing || phase == .verdict { phase = .ready }
    }

    private func enterStep() {
        advanceTask?.cancel()
        timeline = nil
        itemIndex = 0
        attempt = 1
        lastResult = nil
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
