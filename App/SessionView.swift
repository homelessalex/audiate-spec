import AudiateAudio
import AudiateCore
import SwiftUI

/// One uninterrupted pulse: Count-in → Listen → Hold it → Your turn → (verdict while the next count-in
/// ticks) → … Keyboard: Space or the pad taps, 1–4 pick the notation (E2), Esc pauses.
/// AO steps never show notation or any visual rhythm (sound before sight); notation comes from VA on.
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
                case .choosing: AnswerView(runner: runner)
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

/// Shared by the flow and the answer screens so content stays put when the pulse stops.
enum SessionLayout {
    static let headerHeight: CGFloat = 210
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
                    // fixed-height header, shared with AnswerView, so the content below never jumps
                    VStack(spacing: 18) {
                        Text(attempt.map(Self.title) ?? " ").font(.title3).foregroundStyle(.secondary)
                        Text(Self.label(measure?.role, attempt: attempt)).font(.system(size: 44, weight: .bold))
                        Text(attempt.map(Self.detail) ?? " ").foregroundStyle(.secondary)
                        // with the click gone (stage C, E10 silence) the pulse light goes too: the learner keeps it
                        if Self.showsPulse(measure?.role, attempt: attempt) {
                            PulseView(on: Self.isOnMacrobeat(t, measure: measure, attempt: attempt))
                        } else {
                            PulseView(on: false).hidden()
                        }
                    }
                    .frame(height: SessionLayout.headerHeight, alignment: .top)
                    // verdict of the attempt that just ended, shown while the next count-in ticks
                    if let m = measure, m.role == .leadIn || m.role == .countIn,
                       let done = runner.flow.attempt(endingAt: m.start), let verdict = runner.verdicts[done.index] {
                        VerdictBadge(verdict: verdict, pattern: done.pattern)
                    } else if let attempt, attempt.showNotation {
                        // no cursor: where the sound is must be read from the notes, not followed
                        RhythmStaffView(pattern: attempt.pattern, beatGrid: true)
                    } else if let attempt, let q = attempt.question {
                        NotationOptions(question: q, chosen: nil, enabled: false) { _ in }
                    } else if let attempt, attempt.kind == .dictation, measure?.role == .prompt {
                        Text("Listen — then write it, one beat at a time.").font(.title3).foregroundStyle(.secondary)
                    } else if let attempt, attempt.kind == .whichMeter, measure?.role == .prompt {
                        Text("Listen — which meter is it in?").font(.title3).foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 360)
                // the pad shows only for tap attempts
                if let attempt, [.echo, .read, .readWithModel, .holdPulse, .answerDifferently].contains(attempt.kind) {
                    TapPad(recorder: runner.recorder)
                        .frame(maxWidth: 520)
                    if runner.twoHandMode, attempt.kind != .holdPulse {
                        Text("Left hand \(runner.keyMap.pulseLabels): every beat, all the time · Right hand \(runner.keyMap.rhythmLabels) / pad: the rhythm")
                            .font(.callout).foregroundStyle(.secondary)
                        if MIDIInput.shared.isConnected {
                            Text("MIDI: below \(MIDINote.name(runner.midiSplit.lowestRhythmNote)) the beat, from \(MIDINote.name(runner.midiSplit.lowestRhythmNote)) up the rhythm")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("Esc to pause").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    static func title(_ a: FlowSequencer.FlowAttempt) -> String {
        if a.isCorrection { return "Fix it — same pattern again" }
        return switch a.kind {
        case .echo:
            if case .echo(let s) = a.step, s.isAudiationDrill { "Audiate the gap" } else { a.mode == .teaching ? "New pattern" : "Echo" }
        case .readWithModel: "See how it looks"
        case .read: "Read"
        case .nameNotation: "Which notation?"
        case .holdPulse: "Hold the pulse"
        case .dictation: "Dictation"
        case .whichMeter: "Which meter?"
        case .meterFromNotation: "Meter from notation"
        case .sameOrDifferent: "Same or different?"
        case .answerDifferently: "Answer differently"
        case .compose: "Compose"
        }
    }

    static func label(_ role: FlowSequencer.Role?, attempt: FlowSequencer.FlowAttempt?) -> String {
        switch role {
        case .countIn: "Count-in"
        case .leadIn: attempt == nil ? "…" : "Get ready"
        case .prompt: attempt?.kind == .read ? "Look at it" : (attempt?.kind == .readWithModel ? "Listen & look" : "Listen")
        case .hold: attempt?.kind == .read ? "Hear it inside" : "Hold it"
        case .response: attempt?.kind == .answerDifferently ? "Something different" : (attempt?.kind == .echo ? "Your turn" : "Read")
        case .withClick: "Tap the beat"
        case .silent: "Keep the beat"
        case nil: " "
        }
    }

    static func detail(_ a: FlowSequencer.FlowAttempt) -> String {
        var s = a.kind == .holdPulse ? "\(a.item.unitID) warm-up" : "\(a.item.unitID) \(a.item.level.code)"
        if a.mode == .teaching { s += " · try \(a.position.attempt) of \(MasteryPolicy.maxTeachingAttempts)" }
        if a.isCorrection { s += " · try \(a.position.attempt) of \(MasteryPolicy.maxCorrectionAttempts), not graded" }
        if a.mode == .practice { s += " · free practice" }
        s += " · \(Int(a.tempo.bpm.rounded())) \(a.pattern.meter.isUnusual ? "eighths/min" : "BPM")"
        return s
    }

    /// The light follows the click: off where the learner keeps the pulse alone.
    static func showsPulse(_ role: FlowSequencer.Role?, attempt: FlowSequencer.FlowAttempt?) -> Bool {
        guard let role, let attempt else { return true }
        if [.countIn, .leadIn, .withClick].contains(role) { return true }
        if role == .silent || attempt.clickStage == .d { return false }
        if attempt.kind == .whichMeter { return false }
        return !(attempt.clickStage == .c && role == .response)
    }

    static func isOnMacrobeat(_ t: Double, measure: FlowSequencer.Measure?, attempt: FlowSequencer.FlowAttempt?) -> Bool {
        guard let measure else { return false }
        let meter = attempt?.pattern.meter
        let spt = measure.duration / Double(meter?.measureTicks ?? 1)
        let offset = t - measure.start
        return (meter?.macrobeatSpans.map { Double($0.startTick) * spt } ?? [0]).contains { offset >= $0 && offset - $0 < 0.12 }
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
            if let score = verdict.score { AccuracyBar(score: score) }
            if let comparison = verdict.comparison {
                RhythmStaffView(pattern: pattern, zoom: 1.6, beatGrid: true, comparison: comparison)
            }
        }
    }
}

struct NotationOptions: View {
    let question: NameNotationSpec
    let chosen: Int?
    let enabled: Bool
    let choose: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
            ForEach(question.options.indices, id: \.self) { i in
                Button {
                    choose(i)
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Text("\(i + 1)").font(.title3).foregroundStyle(.secondary)
                        RhythmStaffView(pattern: question.options[i], zoom: 1.5)
                        if let chosen, i == question.correctIndex || i == chosen {
                            Image(systemName: i == question.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(i == question.correctIndex ? .green : .red)
                        }
                    }
                    .padding(8)
                    .overlay {
                        if let chosen, i == question.correctIndex || i == chosen {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(i == question.correctIndex ? Color.green : Color.red, lineWidth: 3)
                        }
                    }
                    .opacity(chosen == nil || i == question.correctIndex || i == chosen ? 1 : 0.35)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(!enabled || chosen != nil)
            }
        }
        .frame(maxWidth: 700)
    }
}

/// Mean |error| as a bar: empty = every note dead on, full = at the edge of the tolerance, or a missed
/// note / extra tap. The tick marks where the mean must stay to pass.
struct AccuracyBar: View {
    let score: AccuracyScore

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .yellow, .orange, .red], startPoint: .leading, endPoint: .trailing))
                        .mask(alignment: .leading) {
                            Rectangle().frame(width: max(6, geo.size.width * score.fraction))
                        }
                    if let limit = score.passLimit {
                        Rectangle()
                            .fill(Color.primary.opacity(0.7))
                            .frame(width: 2, height: 18)
                            .offset(x: geo.size.width * limit - 1)
                    }
                }
            }
            .frame(width: 260, height: 12)
            Text(score.isMax ? "Off the scale — a missed note or an extra tap"
                             : String(format: "Average error %.0f ms%@ (scale ends at %.0f ms)", score.meanError * 1000,
                                      score.passLimit.map { String(format: ", pass under %.0f", $0 * score.maximum * 1000) } ?? "",
                                      score.maximum * 1000))
                .font(.caption).foregroundStyle(.secondary)
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
            Text(model.planSession()?.isEmpty != false ? "That's all for today" : "Session ended").font(.largeTitle.bold())
            Text("A level counts once every pattern has been passed on two different days, so new material opens up tomorrow.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
            if !runner.newlyPassed.isEmpty {
                ForEach(runner.newlyPassed, id: \.self) { key in
                    Label("Passed \(key.unitID) \(HomeView.levelName(key.level))", systemImage: "star.fill").foregroundStyle(.green)
                }
            }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: model.now()))!
            Text("Due tomorrow: \(model.progress.dueItems(on: tomorrow).count)").foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Button("Done") { model.endSession() }
                    .controlSize(.large)
                if model.planFreePractice()?.isEmpty == false {
                    Button("Keep practicing") { runner.keepPracticing() }
                        .controlSize(.large)
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                        .help("Practice what you've learned for as long as you like. It doesn't count toward passing a level.")
                }
            }
        }
    }
}
