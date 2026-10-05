import AudiateAudio
import AudiateCore
import SwiftData
import SwiftUI

/// Developer screen (⇧⌘D): play any library pattern as an echo block and grade Space taps.
struct DebugView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var recorder = TapRecorder()
    @State private var patternID = "D-DV-03"
    @State private var bpm = TempoPolicy.dupleBPM
    @State private var stage = ClickStage.b
    @State private var voice = PromptVoice.neutral
    @State private var repeats = 1
    @State private var tapSound = true
    @State private var report: [String] = []

    var body: some View {
        if let library = model.library, let player = model.player {
            content(library: library, player: player)
        } else {
            Text(model.loadError ?? "Not loaded").padding()
        }
    }

    private func content(library: PatternLibrary, player: BlockPlayer) -> some View {
        let pattern = library.pattern(id: patternID)
        return VStack(alignment: .leading, spacing: 12) {
            Form {
                Picker("Pattern", selection: $patternID) {
                    ForEach(library.patterns) { p in
                        Text("\(p.id)  \(p.meter.timeSignature.description)  \((try? SyllableDeriver().line(for: p)) ?? "")").tag(p.id)
                    }
                }
                .onChange(of: patternID) {
                    if let p = library.pattern(id: patternID) { bpm = Tempo.standard(for: p.meter).bpm }
                }
                LabeledContent("Tempo") {
                    HStack {
                        TextField("BPM", value: $bpm, format: .number).frame(width: 60)
                        Stepper("", value: $bpm, in: 30...260, step: 2).labelsHidden()
                        Text(pattern?.meter.isUnusual == true ? "eighth BPM" : "macrobeat BPM").foregroundStyle(.secondary)
                    }
                }
                Picker("Click stage", selection: $stage) {
                    ForEach(ClickStage.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Prompt voice", selection: $voice) {
                    ForEach(PromptVoice.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper("Patterns in block: \(repeats)", value: $repeats, in: 1...6)
                Toggle("Tap sound", isOn: $tapSound)
            }

            HStack {
                Button(recorder.isRunning ? "Stop" : "Play") {
                    recorder.isRunning ? stop(player) : play(pattern, player: player)
                }
                .keyboardShortcut(.return, modifiers: [])
                if recorder.isRunning { Text("Tap Space in each response measure… (\(recorder.tapCount) taps)") }
            }

            Text(latencySummary(player)).font(.caption).foregroundStyle(.secondary)

            ScrollView {
                Text(report.joined(separator: "\n"))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
        .onDisappear { recorder.cancel() }
    }

    private func latencySummary(_ player: BlockPlayer) -> String {
        let device = model.outputDevice
        let offset = context.inputOffset(for: device)
        return String(format: "Output: %@ · output latency %.1f ms · input offset %.1f ms%@",
                      device?.name ?? "unknown", player.outputLatency * 1000, offset * 1000,
                      device.flatMap { context.calibration(for: $0.uid) } == nil ? " (not calibrated)" : "")
    }

    private func play(_ pattern: AudiateCore.Pattern?, player: BlockPlayer) {
        guard let pattern else { return }
        report = []
        do {
            let timeline = try Timeline.echoBlock(patterns: Array(repeating: pattern, count: repeats),
                                                  tempo: Tempo(bpm: bpm), clickStage: stage, voice: voice)
            let compensation = LatencyCompensation(outputLatency: 0, inputOffset: context.inputOffset(for: model.outputDevice))
            let mode = stage.timingMode
            try recorder.run(timeline, player: player, tapSound: tapSound) { rawTaps in
                let taps = rawTaps.map(compensation.blockTime(forRawBlockTime:))
                report = timeline.responses.enumerated().map { i, slot in
                    let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps,
                                                  responseStart: slot.start, responseEnd: slot.end, mode: mode)
                    return Self.describe(grade, index: i + 1, slot: slot, mode: mode)
                }
                print(report.joined(separator: "\n"))
            }
        } catch {
            report = ["Error: \(error)"]
        }
    }

    private func stop(_ player: BlockPlayer) {
        player.stop()
        recorder.cancel()
    }

    static func describe(_ g: OnsetGrade, index: Int, slot: ResponseSlot, mode: TimingMode) -> String {
        var lines = [String(format: "#%d %@ %@  hits %d/%d  misses %d  extras %d  mean %.1f ms  max %.1f ms  tol %.1f ms  acc %.0f%%",
                            index, slot.patternID, g.passed ? "PASS" : "FAIL", g.hits.count, slot.expectedOnsets.count,
                            g.misses.count, g.extras.count, g.meanAbsError * 1000, g.maxAbsError * 1000,
                            g.tolerance * 1000, g.accuracy * 100)]
        if let ratio = g.tempoRatio { lines.append(String(format: "   %@ tempo ratio %.3f", mode.rawValue, ratio)) }
        let errors = g.hits.map { String(format: "%+.0f", $0.error * 1000) }.joined(separator: " ")
        if !errors.isEmpty { lines.append("   errors ms: \(errors)") }
        return lines.joined(separator: "\n")
    }
}
