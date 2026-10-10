import AudiateCore
import SwiftUI

/// The pulse has stopped: answer without a clock (E2, E3, E6, E7). After the answer the result stays
/// on screen briefly (dictation: until Return), then the flow resumes with a count-in.
struct AnswerView: View {
    let runner: SessionRunner

    var body: some View {
        VStack(spacing: 18) {
            if let answered = runner.lastAnswer {
                VStack(spacing: 12) {
                    Text(Self.prompt(answered.attempt)).font(.title3).foregroundStyle(.secondary)
                    ResultHeader(passed: answered.passed)
                }
                .frame(height: SessionLayout.headerHeight, alignment: .bottom)
                content(answered.attempt, choice: answered.choice, written: answered.written, enabled: false)
            } else if let attempt = runner.pendingAnswer {
                VStack(spacing: 12) {
                    Text(Self.prompt(attempt)).font(.title.bold())
                    if let task = Self.task(attempt) {
                        Text(task).multilineTextAlignment(.center).frame(maxWidth: 560)
                    }
                    Text(Self.hint(attempt)).font(.callout).foregroundStyle(.secondary)
                }
                .frame(height: SessionLayout.headerHeight, alignment: .bottom)
                content(attempt, choice: nil, written: nil, enabled: true)
            }
        }
        // same top-anchored layout as the flow screen: the options stay where they were while listening
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func content(_ attempt: FlowSequencer.FlowAttempt, choice: Int?, written: [Cell?]?, enabled: Bool) -> some View {
        switch attempt.step {
        case .nameNotation(let q):
            NotationOptions(question: q, chosen: choice, enabled: enabled) { runner.choose($0) }
        case .whichMeter(let w):
            MeterOptions(meters: w.options.compactMap { runner.library.meters[$0] }, correct: w.correctIndex, chosen: choice,
                         enabled: enabled) { runner.choose($0) }
        case .meterFromNotation(let m):
            // options first, so four staves never push them out of the window; the staves scroll if needed.
            // The time signature and the beat grid are hidden: the beaming and values tell the meter.
            MeterOptions(meters: m.options.compactMap { runner.library.meters[$0] }, correct: m.correctIndex, chosen: choice,
                         enabled: enabled) { runner.choose($0) }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(m.series.indices, id: \.self) { i in
                        RhythmStaffView(pattern: m.series[i], zoom: 1.5, showTimeSignature: choice != nil)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        case .sameOrDifferent(let d):
            SameDifferentOptions(isSame: d.isSame, chosen: choice, enabled: enabled) { runner.choose($0) }
        case .compose(let c):
            if let meter = runner.library.meters[c.meterID] {
                CellComposer(palette: c.palette, meter: meter, action: "Perform it") { runner.submit(composition: $0.compactMap { $0 }) }
            }
        case .dictation(let d):
            if let written {
                DictationResult(spec: d, pattern: attempt.pattern, written: written) { runner.continueAfterAnswer() }
            } else {
                CellComposer(palette: d.palette, meter: attempt.pattern.meter, action: "Check") { runner.submit(dictation: $0) }
            }
        default:
            EmptyView()
        }
    }

    static func prompt(_ a: FlowSequencer.FlowAttempt) -> String {
        switch a.kind {
        case .nameNotation: "Which notation did you hear?"
        case .whichMeter: "Which meter was it?"
        case .meterFromNotation: "Which meter are these in?"
        case .dictation: "Write what you heard"
        case .sameOrDifferent: "Same or different?"
        case .compose: "Write your own pattern"
        default: ""
        }
    }

    /// What to do, in words, for the screens that are more than "pick one".
    static func task(_ a: FlowSequencer.FlowAttempt) -> String? {
        switch a.kind {
        case .dictation:
            "Put the pattern together beat by beat. The blue box is the beat you are filling: click the "
                + "piece below that sounds like that beat (or press its number), and the box moves on to the next beat."
        case .meterFromNotation:
            "No sound this time: read the four patterns and tell their meter from the beaming and the note values."
        case .compose:
            "Make up a pattern of your own: pick a piece for each beat. Then you tap it in time with the click."
        default: nil
        }
    }

    static func hint(_ a: FlowSequencer.FlowAttempt) -> String {
        switch a.kind {
        case .dictation: "← → choose a beat · ⌫ empty it · Return checks · Esc pauses"
        case .compose: "← → choose a beat · ⌫ empty it · Return to perform · Esc pauses"
        default: "Click or press a number. Esc to pause."
        }
    }
}

private struct ResultHeader: View {
    let passed: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(passed ? .green : .red)
            Text(passed ? "Yes" : "No").font(.title.bold())
        }
    }
}

private struct MeterOptions: View {
    let meters: [Meter]
    let correct: Int
    let chosen: Int?
    let enabled: Bool
    let choose: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(meters.indices, id: \.self) { i in
                Button {
                    choose(i)
                } label: {
                    HStack {
                        Text("\(i + 1)").foregroundStyle(.secondary)
                        Text(SessionRunner.meterName(meters[i])).font(.title3)
                        if let chosen, i == correct || i == chosen {
                            Image(systemName: i == correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(i == correct ? .green : .red)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .controlSize(.large)
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(!enabled || chosen != nil)
            }
        }
    }
}

private struct SameDifferentOptions: View {
    let isSame: Bool
    let chosen: Int?
    let enabled: Bool
    let choose: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            ForEach(0..<2, id: \.self) { i in
                let right = (i == 0) == isSame
                Button {
                    choose(i)
                } label: {
                    HStack {
                        Text("\(i + 1)").foregroundStyle(.secondary)
                        Text(i == 0 ? "Same" : "Different").font(.title3)
                        if let chosen, right || i == chosen {
                            Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(right ? .green : .red)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .controlSize(.large)
                .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: [])
                .disabled(!enabled || chosen != nil)
            }
        }
    }
}

/// One cell as a tiny staff (no time signature).
private struct CellTile: View {
    let cell: Cell
    let allowsThirds: Bool
    var zoom: CGFloat = 1.3

    var body: some View {
        let meter = Meter(id: "cell\(cell.macrobeatSize)", macrobeats: [cell.macrobeatSize], allowsThirds: allowsThirds,
                          timeSignature: TimeSignature(beats: cell.macrobeatSize, beatUnit: 8))
        if let pattern = Dictation.pattern(from: [cell], meter: meter, id: cell.tokens.map(\.description).joined(separator: " ")) {
            RhythmStaffView(pattern: pattern, zoom: zoom, showTimeSignature: false)
        }
    }
}

/// One cell per macrobeat from a palette (E6 dictation, E9 composing).
private struct CellComposer: View {
    let palette: [Cell]
    let meter: Meter
    let action: String
    let submit: ([Cell?]) -> Void
    @State private var slots: [Cell?] = []
    @State private var current = 0
    @FocusState private var focused: Bool

    var body: some View {
        let palette = self.palette.filter { $0.macrobeatSize == meter.macrobeats[safe: current] }
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                ForEach(meter.macrobeats.indices, id: \.self) { i in
                    Button { current = i } label: {
                        Group {
                            if let cell = slots[safe: i] ?? nil {
                                CellTile(cell: cell, allowsThirds: meter.allowsThirds)
                            } else {
                                VStack(spacing: 4) {
                                    Text("beat \(i + 1)").foregroundStyle(.secondary)
                                    if i == current { Text("pick below ↓").font(.caption).foregroundStyle(Color.accentColor) }
                                }
                                .frame(width: 110, height: 70)
                            }
                        }
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(i == current ? Color.accentColor : .secondary.opacity(0.4),
                                                                               lineWidth: i == current ? 3 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            // as many columns as cells (up to 4), so a short palette sits centred under the beats
            let columns = max(1, min(palette.count, 4))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 150), spacing: 10), count: columns), spacing: 10) {
                ForEach(palette.indices, id: \.self) { k in
                    Button { pick(palette[k]) } label: {
                        HStack {
                            Text("\(k + 1)").foregroundStyle(.secondary)
                            CellTile(cell: palette[k], allowsThirds: meter.allowsThirds, zoom: 1.1)
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(k < 9 ? KeyboardShortcut(KeyEquivalent(Character("\(k + 1)")), modifiers: []) : nil)
                }
            }
            .frame(maxWidth: CGFloat(columns) * 180)
            Button(action) { submit(slots) }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(slots.contains { $0 == nil })
        }
        .focusable()
        // keys only: macOS draws the focus ring as a stray box beside the beats
        .focusEffectDisabled()
        .focused($focused)
        .onAppear {
            slots = Array(repeating: nil, count: meter.macrobeats.count)
            focused = true
        }
        .onKeyPress(.leftArrow) { current = max(0, current - 1); return .handled }
        .onKeyPress(.rightArrow) { current = min(meter.macrobeats.count - 1, current + 1); return .handled }
        .onKeyPress(.delete) { if slots.indices.contains(current) { slots[current] = nil }; return .handled }
    }

    private func pick(_ cell: Cell) {
        guard slots.indices.contains(current) else { return }
        slots[current] = cell
        if current + 1 < slots.count { current += 1 }
    }
}

/// From SA on notation and comparison are allowed: the answer, and what was written, the first wrong beat marked.
private struct DictationResult: View {
    let spec: DictationSpec
    let pattern: AudiateCore.Pattern
    let written: [Cell?]
    let next: () -> Void

    var body: some View {
        let wrong = Dictation.firstDifference(answer: spec.answer, written: written)
        VStack(spacing: 14) {
            Text("It was").foregroundStyle(.secondary)
            RhythmStaffView(pattern: pattern, zoom: 1.8, beatGrid: true)
            if let wrong {
                Text("You wrote — beat \(wrong + 1) differs").foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(written.indices, id: \.self) { i in
                        Group {
                            if let cell = written[i] { CellTile(cell: cell, allowsThirds: pattern.meter.allowsThirds) } else { Text("—") }
                        }
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(i == wrong ? Color.red : .clear, lineWidth: 3))
                    }
                }
            }
            Button("Continue") { next() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Visual check of the answer screens with made-up data. Launch with `-AudiateAnswerSheet /path/answers.png`.
struct AnswerPreviewSheet: View {
    let library: PatternLibrary

    static func sampleDrift(_ library: PatternLibrary) -> PulseTrainer.Result {
        var t = PulseTrainer(settings: .init(meter: library.meters["usual_duple"]!, tempo: Tempo(bpm: 80),
                                             subdivision: .macrobeats, mode: .blocks))
        let beats = t.cycles[0].beats
        return t.report(taps: beats.enumerated().map { beats[0] + Double($0.offset) * 0.75 * 1.03 })!
    }

    /// A four-measure phrase read with the third measure's second note missed and the last one late.
    static func samplePhrase(_ library: PatternLibrary) -> ([AudiateCore.Pattern], SessionRunner.PhraseReview) {
        let phrase = ["D-MM-02", "D-DV-01", "D-MM-04", "D-DV-03"].compactMap { library.pattern(id: $0) }
        let tempo = Tempo(bpm: 56)
        let timeline = try! Timeline.phraseBlock(patterns: phrase, tempo: tempo, clickStage: .b)
        var taps = timeline.responses.flatMap(\.expectedOnsets).map { $0 + 0.012 }
        let third = timeline.responses[0].expectedOnsets.count + timeline.responses[1].expectedOnsets.count
        taps.remove(at: third + 1)
        taps[taps.count - 1] += 0.06
        let grade = PhraseGrade.grade(slots: timeline.responses, taps: taps, pulseTaps: nil, mode: .absolute)
        let review = SessionRunner.PhraseReview(
            comparisons: phrase.indices.map {
                SessionRunner.comparison(grade.rhythm[$0], pattern: phrase[$0], downbeat: timeline.responses[$0].start, tempo: tempo)
            },
            measurePassed: phrase.indices.map(grade.measurePassed),
            reasons: ["Measure 3: missed a beat", "Measure 4: missed a beat, extra tap"])
        return (phrase, review)
    }

    var body: some View {
        let target = library.pattern(id: "D-MM-03")!
        let answer = Dictation.cells(for: target, in: library)!
        let palette = Dictation.palette(for: target.meter, contents: [.macroMicro, .division], answer: answer, library: library)
        let spec = DictationSpec(item: PlannedItem(patternID: target.id, unitID: "U1", level: .symbolic, purpose: .new),
                                 tempo: Tempo(bpm: 80), answer: answer, palette: palette, mode: .evaluation)
        let series = ["T-MM-02", "T-MM-04", "T-MM-01", "T-MM-03"].compactMap { library.pattern(id: $0) }
        VStack(alignment: .leading, spacing: 28) {
            Text("Dictation input").font(.headline)
            CellComposer(palette: spec.palette, meter: target.meter, action: "Check") { _ in }
            Text("Dictation result (beat 2 wrong)").font(.headline)
            DictationResult(spec: spec, pattern: target, written: [answer[0], answer[0]]) {}
            Text("Meter from notation").font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(series.indices, id: \.self) { RhythmStaffView(pattern: series[$0], zoom: 1.5, showTimeSignature: false) }
            }
            MeterOptions(meters: ["usual_duple", "usual_triple"].compactMap { library.meters[$0] }, correct: 1, chosen: 0, enabled: false) { _ in }
            Text("Phrase while reading").font(.headline)
            PhraseStaffView(phrase: Self.samplePhrase(library).0)
            Text("Phrase review (in the measures after the phrase)").font(.headline)
            PhraseVerdict(passed: false, phrase: Self.samplePhrase(library).0, review: Self.samplePhrase(library).1)
            Text("Pulse trainer: after a silence (late, slowed down)").font(.headline)
            DriftCard(result: Self.sampleDrift(library), clickBPM: 80)
        }
        .padding(24)
        .frame(width: 820)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
