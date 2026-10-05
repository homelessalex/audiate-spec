import AudiateCore
import SwiftUI

/// Full-window session. Keyboard-first: Space (or the pad) taps, Return continues, Esc pauses.
/// No notation and no visual rhythm here: M2 covers AO and VA only (sound before sight).
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
                case .feedback: EchoFeedbackView(runner: runner)
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
            if let spec = runner.echoSpec {
                Text(spec.mode == .teaching ? "New pattern" : "Echo").font(.title.bold())
                Text(Self.instructions(spec)).multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
                Text("\(spec.items.count) patterns · \(spec.mode == .teaching ? "teaching" : "evaluation") · \(spec.items[0].level.code)")
                    .font(.callout.monospaced()).foregroundStyle(.secondary)
            }
            Button("Start") { runner.startEcho() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    static func instructions(_ spec: EchoBlockSpec) -> String {
        var s = "After the count-in you hear a pattern; tap it back right away in the next measure (Space or click the pad). The pulse keeps going."
        if spec.showSyllables { s += " Chant the syllables aloud as you tap." }
        if spec.mode == .evaluation { s += " This round counts toward mastery." }
        return s
    }
}

private struct EchoPlayingView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 24) {
            TimelineView(.animation) { _ in
                if let timeline = runner.timeline, let spec = runner.echoSpec {
                    let state = PlaybackState(timeline: timeline, meter: runner.echoMeter, time: runner.recorder.heardTime())
                    VStack(spacing: 22) {
                        Text(state.label).font(.system(size: 40, weight: .bold))
                        Text(state.counter).foregroundStyle(.secondary)
                        PulseView(beat: state.beat)
                        if spec.showSyllables, let cues = state.cues {
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

/// What to show at the current heard time: phase, pulse, syllables.
private struct PlaybackState {
    let label: String
    let counter: String
    /// nil, or whether the current flash is a strong (macro) beat.
    let beat: Bool?
    let cues: [SyllableCue]?
    let highlightedCue: Int?

    init(timeline: Timeline, meter: Meter?, time: Double?) {
        let n = timeline.prompts.count
        guard let t = time, t >= 0 else {
            label = "Get ready"; counter = ""; beat = nil; cues = nil; highlightedCue = nil
            return
        }
        let measure = timeline.measureDuration
        let m = Int(t / measure)
        let inMeasure = t - Double(m) * measure
        let spt = measure / Double(meter?.measureTicks ?? 1)
        let macroStarts = meter?.macrobeatSpans.map { Double($0.startTick) * spt } ?? [0]
        beat = macroStarts.contains { inMeasure >= $0 && inMeasure - $0 < 0.12 } ? true : nil

        let k = m == 0 ? nil : (m - 1) / 2
        switch m {
        case 0: label = "Count-in"
        case _ where t >= timeline.duration: label = "…"
        case _ where m % 2 == 1: label = "Listen"
        default: label = "Your turn"
        }
        counter = k.map { "Pattern \(min($0 + 1, n)) of \(n)" } ?? ""
        if let k, k < n {
            let prompt = timeline.prompts[k]
            cues = prompt.cues
            let local = m % 2 == 1 ? t : t - measure // in the response, follow the same positions one measure later
            highlightedCue = prompt.cues.firstIndex { local >= $0.time && local < $0.time + $0.duration }
        } else {
            cues = nil
            highlightedCue = nil
        }
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

private struct EchoFeedbackView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 18) {
            let passed = runner.results.filter(\.grade.passed).count
            Text("\(passed) of \(runner.results.count) correct").font(.title.bold())
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(runner.results) { r in
                        HStack(spacing: 14) {
                            Image(systemName: r.grade.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(r.grade.passed ? .green : .red)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                if r.item.level >= .verbal { Text(r.syllables).font(.title3.monospaced()) }
                                Text(Self.counts(r.feedback)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Model vs. you") { runner.replay(r) }
                        }
                    }
                }
                .frame(maxWidth: 560)
            }
            Button("Continue") { runner.next() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    static func counts(_ f: EchoFeedback) -> String {
        var parts = ["\(f.onTime) on time"]
        if f.early > 0 { parts.append("\(f.early) early") }
        if f.late > 0 { parts.append("\(f.late) late") }
        if f.missed > 0 { parts.append("\(f.missed) missed") }
        if f.extra > 0 { parts.append("\(f.extra) extra") }
        return parts.joined(separator: " · ")
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
