import AudiateCore
import SwiftUI

/// One uninterrupted pulse: Count-in → Listen → Hold it → Your turn → (verdict while the next count-in
/// ticks) → … Keyboard: Space or the pad taps, 1–4 answer "name the syllables", Esc pauses.
/// Ear steps never show notation or any visual rhythm (sound before sight).
struct SessionView: View {
    @Environment(AppModel.self) private var model
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("End session") {
                    runner.end()
                }
            }
            Group {
                switch runner.state {
                case .running: FlowView(runner: runner)
                case .paused: PausedView(runner: runner)
                case .finished: SummaryView(runner: runner)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if let error = runner.error { Text(error).foregroundStyle(.red) }
            Button("Pause") { runner.pause() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        .padding(28)
        .onAppear { runner.start() }
    }
}

private struct FlowView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 22) {
            TimelineView(.animation) { _ in
                let t = runner.heardTime ?? -1
                let measure = runner.flow.measure(at: t)
                let attempt = measure?.attemptIndex.map { runner.flow.attempts[$0] }
                VStack(spacing: 18) {
                    Text(attempt.map(Self.title) ?? " ").font(.title3).foregroundStyle(.secondary)
                    Text(Self.label(measure?.role, attempt: attempt)).font(.system(size: 44, weight: .bold))
                    Text(attempt.map(Self.detail) ?? " ").foregroundStyle(.secondary)
                    PulseView(on: Self.isOnMacrobeat(t, measure: measure, attempt: attempt))
                    // verdict of the attempt that just ended, shown while the next count-in ticks
                    if let m = measure, m.role == .leadIn || m.role == .countIn,
                       let done = runner.flow.attempt(endingAt: m.start), let verdict = runner.verdicts[done.index] {
                        VerdictBadge(verdict: verdict, pattern: done.pattern)
                    } else if let attempt, attempt.showSyllables, let role = measure?.role {
                        SyllableLine(cues: attempt.prompt.cues, highlighted: Self.cue(t, role: role, attempt: attempt))
                    } else if let attempt, attempt.kind == .read || attempt.kind == .readWithModel {
                        RhythmStaffView(pattern: attempt.pattern, beatGrid: true,
                                        currentTick: Self.readingTick(t, role: measure?.role, attempt: attempt))
                    }
                    if let attempt, let q = attempt.question {
                        QuestionOptions(runner: runner, attempt: attempt, question: q)
                    }
                }
                .frame(minHeight: 360)
            }
            TapPad(recorder: runner.recorder)
                .frame(maxWidth: 520)
            Text("Esc to pause").font(.caption).foregroundStyle(.secondary)
        }
    }

    static func title(_ a: FlowSequencer.FlowAttempt) -> String {
        switch a.kind {
        case .echo: a.mode == .teaching ? "New pattern" : "Echo"
        case .readWithModel: "See how it looks"
        case .read: "Read"
        case .nameSyllables: "Name the syllables"
        }
    }

    static func label(_ role: FlowSequencer.Role?, attempt: FlowSequencer.FlowAttempt?) -> String {
        switch role {
        case .countIn: "Count-in"
        case .leadIn: attempt == nil ? "…" : "Get ready"
        case .prompt: attempt?.kind == .read ? "Look ahead" : "Listen"
        case .hold: "Hold it"
        case .response: attempt?.kind == .echo ? "Your turn" : "Read"
        case .answer: "Choose"
        case nil: " "
        }
    }

    static func detail(_ a: FlowSequencer.FlowAttempt) -> String {
        var s = "\(a.item.unitID) \(a.item.level.code)"
        if a.mode == .teaching { s += " · try \(a.position.attempt) of \(MasteryPolicy.maxTeachingAttempts)" }
        s += " · \(Int(a.tempo.bpm.rounded())) \(a.pattern.meter.isUnusual ? "eighths/min" : "BPM")"
        return s
    }

    static func isOnMacrobeat(_ t: Double, measure: FlowSequencer.Measure?, attempt: FlowSequencer.FlowAttempt?) -> Bool {
        guard let measure else { return false }
        let meter = attempt?.pattern.meter
        let spt = measure.duration / Double(meter?.measureTicks ?? 1)
        let offset = t - measure.start
        return (meter?.macrobeatSpans.map { Double($0.startTick) * spt } ?? [0]).contains { offset >= $0 && offset - $0 < 0.12 }
    }

    /// Syllable cues are timed in the prompt measure; in the response they follow the same positions.
    static func cue(_ t: Double, role: FlowSequencer.Role, attempt: FlowSequencer.FlowAttempt) -> Int? {
        let local: Double
        switch role {
        case .prompt: local = t
        case .response: local = t - (attempt.response.map { $0.end - attempt.measureDuration } ?? t) + (attempt.prompt.end - attempt.measureDuration)
        default: return nil
        }
        return attempt.prompt.cues.firstIndex { local >= $0.time && local < $0.time + $0.duration }
    }

    static func readingTick(_ t: Double, role: FlowSequencer.Role?, attempt: FlowSequencer.FlowAttempt) -> Double? {
        let spt = attempt.tempo.secondsPerTick(in: attempt.pattern.meter)
        switch role {
        case .response: return attempt.response.map { (t - ($0.end - attempt.measureDuration)) / spt }
        case .prompt where attempt.kind == .readWithModel: return (t - (attempt.prompt.end - attempt.measureDuration)) / spt
        default: return nil
        }
    }
}

private struct VerdictBadge: View {
    let verdict: SessionRunner.Verdict
    let pattern: AudiateCore.Pattern

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Image(systemName: verdict.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(verdict.passed ? .green : .red)
                Text(verdict.passed ? "Yes" : "No").font(.system(size: 36, weight: .bold))
            }
            ForEach(verdict.reasons, id: \.self) { Text($0).font(.title3) }
            if let answer = verdict.answer, !verdict.passed {
                Text(answer).font(.title3.monospaced()).foregroundStyle(.secondary)
            }
            if let comparison = verdict.comparison {
                RhythmStaffView(pattern: pattern, zoom: 1.6, beatGrid: true, comparison: comparison)
            }
        }
    }
}

private struct QuestionOptions: View {
    let runner: SessionRunner
    let attempt: FlowSequencer.FlowAttempt
    let question: NameSyllablesSpec

    var body: some View {
        let chosen = runner.choices[attempt.index]
        VStack(spacing: 8) {
            ForEach(question.options.indices, id: \.self) { i in
                Button {
                    runner.choose(i)
                } label: {
                    HStack {
                        Text("\(i + 1)").foregroundStyle(.secondary)
                        Text(question.options[i]).font(.title3.monospaced())
                        Spacer()
                        if chosen == i { Image(systemName: "hand.point.left.fill") }
                    }
                    .frame(width: 360)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(chosen != nil)
            }
        }
    }
}

private struct PulseView: View {
    let on: Bool

    var body: some View {
        Circle()
            .fill(on ? Color.accentColor : Color.secondary.opacity(0.15))
            .frame(width: 56, height: 56)
            .animation(.easeOut(duration: 0.08), value: on)
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

private struct PausedView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 18) {
            Text("Paused").font(.largeTitle.bold())
            Text("Resume starts the current pattern again with a count-in.").foregroundStyle(.secondary)
            Button("Resume") { runner.start() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
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
