import AudiateCore
import SwiftUI

/// Full-window session. Keyboard-first: Space (or the pad) taps, Return continues, Esc pauses.
/// Ear steps never show notation or any visual rhythm; reading steps exist only from SA on (sound before sight).
struct SessionView: View {
    @Environment(AppModel.self) private var model
    let runner: SessionRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Step \(min(runner.stepIndex + 1, runner.plan.steps.count)) of \(runner.plan.steps.count)")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("End session") { model.endSession() }
            }
            .padding(.bottom, 16)

            Group {
                switch runner.phase {
                case .ready: EchoReadyView(runner: runner)
                case .playing: EchoPlayingView(runner: runner)
                case .verdict: VerdictView(runner: runner)
                case .question: QuestionView(runner: runner)
                case .summary: SummaryView(runner: runner)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let error = runner.error { Text(error).foregroundStyle(.red) }
            Button("Pause") { runner.pause() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        .padding(28)
    }
}

private struct EchoReadyView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 18) {
            if let block = runner.block {
                Text(Self.title(block)).font(.title.bold())
                Text(Self.instructions(block)).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                Text("\(block.items.count) \(block.items.count == 1 ? "pattern" : "patterns") · \(block.mode == .teaching ? "teaching" : "evaluation") · \(block.items[0].level.code)")
                    .font(.callout.monospaced()).foregroundStyle(.secondary)
                if runner.itemIndex > 0 || runner.attempt > 1 {
                    Text("Paused — continues with pattern \(runner.itemIndex + 1), try \(runner.attempt)").foregroundStyle(.secondary)
                }
                if block.showsNotation, let item = runner.currentItem, let p = runner.pattern(item.patternID) {
                    RhythmStaffView(pattern: p, beatGrid: true)
                }
            }
            Button("Start") { runner.startBlock() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    static func title(_ block: SessionRunner.TapBlock) -> String {
        switch block.kind {
        case .echo: block.mode == .teaching ? "New pattern" : "Echo"
        case .readWithModel: "See how it looks"
        case .read: "Read"
        }
    }

    static func instructions(_ block: SessionRunner.TapBlock) -> String {
        var s: String
        switch block.kind {
        case .echo:
            s = "Count-in, then you hear a pattern. Hold it in your head for one measure, then tap it back (Space or the pad)."
            if block.showSyllables { s += " Chant the syllables aloud as you tap." }
            s += block.mode == .teaching
                ? " You'll hear right away whether it was right; the pattern repeats until you get it."
                : " One try per pattern — this round counts toward mastery."
        case .readWithModel:
            s = "Watch the notation while the pattern plays, then read it back in the next measure."
        case .read:
            s = "The pattern appears one measure early. Read it when its measure comes — tap and chant."
        }
        return s
    }
}

private struct EchoPlayingView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 24) {
            TimelineView(.animation) { _ in
                if let timeline = runner.timeline, let block = runner.block {
                    let state = PlaybackState(timeline: timeline, block: block, meter: runner.blockMeter,
                                              time: runner.recorder.heardTime())
                    VStack(spacing: 22) {
                        Text(state.label).font(.system(size: 40, weight: .bold))
                        Text(runner.progressLabel).foregroundStyle(.secondary)
                        PulseView(beat: state.beat)
                        if block.showsNotation, let item = runner.currentItem, let p = runner.pattern(item.patternID) {
                            // the beat grid ties the notes to the pulse; the cursor and lit note show what sounds now
                            RhythmStaffView(pattern: p, beatGrid: true, currentTick: state.showsCursor ? state.tick : nil,
                                            liveTaps: state.isResponse ? runner.liveTaps(responseIndex: 0) : [])
                        }
                        if block.showSyllables, let cues = state.cues {
                            SyllableLine(cues: cues, highlighted: state.highlightedCue)
                        }
                    }
                }
            }
            TapPad(recorder: runner.recorder)
                .frame(maxWidth: 520)
            Text("Esc to pause").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// What to show at the current heard time: phase, pulse, pattern, playhead, syllables.
private struct PlaybackState {
    var label = "Get ready"
    /// Whether a macrobeat flash is on.
    var beat: Bool?
    var patternIndex: Int?
    /// Measure-relative tick in the prompt or response measure.
    var tick: Double?
    var isResponse = false
    /// Cursor while the pattern sounds (model) or is being read (response); not during look-ahead.
    var showsCursor = false
    var cues: [SyllableCue]?
    var highlightedCue: Int?

    init(timeline: Timeline, block: SessionRunner.TapBlock, meter: Meter?, time: Double?) {
        guard let t = time, t >= 0 else {
            patternIndex = 0
            return
        }
        let measure = timeline.measureDuration
        let m = Int(t / measure)
        let inMeasure = t - Double(m) * measure
        let spt = measure / Double(meter?.measureTicks ?? 1)
        let macroStarts = meter?.macrobeatSpans.map { Double($0.startTick) * spt } ?? [0]
        beat = macroStarts.contains { inMeasure >= $0 && inMeasure - $0 < 0.12 } ? true : nil

        guard let role = timeline.role(at: t) else {
            label = "…"
            return
        }
        let i: Int
        switch role {
        case .countIn:
            label = "Count-in"
            patternIndex = 0
            return
        case .prompt(let k):
            i = k
            label = switch block.kind {
            case .echo: "Listen"
            case .readWithModel: "Listen & look"
            case .read: "Look ahead"
            }
        case .hold(let k):
            i = k
            label = "Hold it"
        case .response(let k):
            i = k
            label = block.kind == .echo ? "Your turn" : "Read"
        }
        patternIndex = i
        if case .hold = role { return }
        tick = inMeasure / spt
        if case .response = role { isResponse = true }
        showsCursor = isResponse || block.kind == .readWithModel
        // syllable cues are timed for the prompt measure; follow the same positions in the response
        let promptMeasure = timeline.measureRoles.firstIndex(of: .prompt(i)) ?? m
        let local = t - Double(m - promptMeasure) * measure
        cues = timeline.prompts[i].cues
        highlightedCue = cues?.firstIndex { local >= $0.time && local < $0.time + $0.duration }
    }
}

private struct PulseView: View {
    let beat: Bool?

    var body: some View {
        Circle()
            .fill(beat != nil ? Color.accentColor : Color.secondary.opacity(0.15))
            .frame(width: 56, height: 56)
            .animation(.easeOut(duration: 0.08), value: beat != nil)
    }
}

struct SyllableLine: View {
    let cues: [SyllableCue]
    let highlighted: Int?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(cues.indices, id: \.self) { i in
                Text(cues[i].text)
                    .font(.system(size: 30, weight: i == highlighted ? .bold : .regular, design: .rounded))
                    .foregroundStyle(i == highlighted ? Color.accentColor : (cues[i].kind == .note ? Color.primary : Color.secondary))
            }
        }
    }
}

/// Yes or no, right after the attempt. Ear steps move on by themselves; reading (from SA) shows the
/// notes-vs-taps comparison and waits for Return.
private struct VerdictView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 20) {
            if let r = runner.lastResult {
                Image(systemName: r.grade.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(r.grade.passed ? .green : .red)
                Text(r.grade.passed ? "Yes" : "No").font(.system(size: 40, weight: .bold))
                ForEach(r.grade.errors, id: \.self) { error in
                    Text(Self.describe(error)).font(.title3)
                }
                Text(runner.willRetry ? "Again" : " ").font(.title2).foregroundStyle(.secondary)
                if runner.block?.showsNotation == true {
                    RhythmStaffView(pattern: r.pattern, zoom: 1.7, beatGrid: true, comparison: r.comparison)
                    Button("Continue") { runner.advance() }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    static func describe(_ error: AttemptError) -> String {
        switch error {
        case .missedBeat: "Missed a beat"
        case .extraTap: "Extra tap"
        case .timingOff: "Timing off"
        }
    }
}

private struct QuestionView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 20) {
            Text("Name the syllables").font(.title.bold())
            Text("Listen to the pattern, then pick its syllables (keys 1–\(runner.question?.spec.options.count ?? 4)).")
                .foregroundStyle(.secondary)
            if let q = runner.question {
                Button(q.plays == 0 ? "Play" : "Replay") { runner.playQuestion() }
                    .disabled(!runner.canReplayQuestion)
                VStack(spacing: 10) {
                    ForEach(q.spec.options.indices, id: \.self) { i in
                        Button {
                            runner.choose(i)
                        } label: {
                            HStack {
                                Text("\(i + 1)").foregroundStyle(.secondary)
                                Text(q.spec.options[i]).font(.title3.monospaced())
                                Spacer()
                                if let chosen = q.chosen, i == q.spec.correctIndex || i == chosen {
                                    Image(systemName: i == q.spec.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(i == q.spec.correctIndex ? .green : .red)
                                }
                            }
                            .frame(width: 380)
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                        .disabled(q.chosen != nil || q.plays == 0)
                    }
                }
                if q.chosen != nil {
                    Button("Continue") { runner.next() }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .onAppear { if runner.question?.plays == 0 { runner.playQuestion() } }
    }
}

private struct SummaryView: View {
    @Environment(AppModel.self) private var model
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 16) {
            Text("Session complete").font(.largeTitle.bold())
            if runner.newlyPassed.isEmpty {
                Text("Keep going — mastery needs passes on at least two different days.").foregroundStyle(.secondary)
            } else {
                ForEach(runner.newlyPassed, id: \.self) { key in
                    Label("Passed \(key.unitID) \(HomeView.levelName(key.level))", systemImage: "star.fill").foregroundStyle(.green)
                }
            }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: model.now()))!
            Text("Due tomorrow: \(model.progress.dueItems(on: tomorrow).count)").foregroundStyle(.secondary)
            Button("Done") { model.endSession() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}
