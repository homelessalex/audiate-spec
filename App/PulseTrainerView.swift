import AudiateCore
import Charts
import SwiftUI

/// Pulse trainer: click / silence / click …; after each silence, how far and which way you drifted.
struct PulseTrainerView: View {
    @Environment(AppModel.self) private var model
    let runner: PulseTrainerRunner

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Pulse trainer").font(.title2.bold())
                Spacer()
                Button("Close") {
                    runner.stop()
                    model.closePulseTrainer()
                }
            }
            .padding(.bottom, 12)
            Group {
                switch runner.state {
                case .setup: PulseSetup(runner: runner)
                case .running: PulseRunning(runner: runner)
                case .finished: PulseSummary(runner: runner)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            Button("Stop") { runner.stop() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
        .padding(28)
    }
}

private struct PulseSetup: View {
    @Bindable var runner: PulseTrainerRunner

    var body: some View {
        let meter = runner.settings.meter
        let range = meter.isUnusual ? 120.0...260.0 : (meter.macrobeats.first == 3 ? 36.0...100.0 : 40.0...140.0)
        VStack(spacing: 18) {
            Text("The click plays, then goes silent: keep tapping the beat. When it comes back you'll hear how far you drifted — settle back in and go again. Steady → longer silences.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 520)
            Form {
                Picker("Meter", selection: $runner.settings.meter) {
                    ForEach(runner.meters, id: \.self) { Text(SessionRunner.meterName($0)).tag($0) }
                }
                .onChange(of: runner.settings.meter) { runner.settings.tempo = .standard(for: runner.settings.meter) }
                LabeledContent("Tempo") {
                    HStack {
                        Slider(value: Binding(get: { runner.settings.tempo.bpm }, set: { runner.settings.tempo = Tempo(bpm: $0.rounded()) }),
                               in: range)
                        Text("\(Int(runner.settings.tempo.bpm)) \(meter.isUnusual ? "eighths/min" : "BPM")").monospacedDigit().frame(width: 110)
                    }
                }
                Picker("Tap", selection: $runner.settings.subdivision) {
                    Text("Beats").tag(PulseTrainer.Subdivision.macrobeats)
                    Text("Beats + halves/thirds").tag(PulseTrainer.Subdivision.microbeats)
                    Text("Fine grid").tag(PulseTrainer.Subdivision.divisions)
                }
                .pickerStyle(.segmented)
                Picker("Silence", selection: $runner.settings.mode) {
                    Text("Blocks (2 → 16 measures)").tag(PulseTrainer.Mode.blocks)
                    Text("Random dropouts").tag(PulseTrainer.Mode.randomDropouts)
                }
                .pickerStyle(.segmented)
            }
            .formStyle(.grouped)
            .frame(maxWidth: 560)
            Button("Start") { runner.start() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}

private struct PulseRunning: View {
    let runner: PulseTrainerRunner

    var body: some View {
        VStack(spacing: 22) {
            TimelineView(.animation) { _ in
                let t = runner.heardTime ?? -1
                let m = runner.trainer?.measure(at: t)
                VStack(spacing: 18) {
                    if m?.role == .silent {
                        Text("Keep it").font(.system(size: 44, weight: .bold))
                        Text(runner.settings.mode == .blocks ? "measure \(m!.indexInRun) of \(m!.runLength)" : "…")
                            .font(.title3).foregroundStyle(.secondary)
                    } else {
                        Text(t < 0 ? "Get ready" : "With the click").font(.system(size: 44, weight: .bold))
                        if let last = runner.results.last { DriftCard(result: last, clickBPM: runner.settings.tempo.bpm) } else {
                            Text("Lock in with the click, then keep going on your own.").foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(minHeight: 260)
            }
            TapPad(recorder: runner.recorder).frame(maxWidth: 520)
            Text("Any tap key or the pad · Esc to stop").font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Where the last silence ended: a needle from early to late, the tempo you implied, and evenness.
struct DriftCard: View {
    let result: PulseTrainer.Result
    let clickBPM: Double

    var body: some View {
        VStack(spacing: 10) {
            DriftNeedle(drift: result.driftBeats)
            Text(Self.driftText(result)).font(.title3)
            HStack(spacing: 18) {
                Text(Self.tempoText(result, clickBPM: clickBPM))
                Text(result.grade.problems.contains(.uneven) ? "Uneven beats" : "Even beats")
                if result.grade.problems.contains(.lostCount) { Text("Lost count").foregroundStyle(.red) }
            }
            .foregroundStyle(.secondary)
        }
    }

    static func driftText(_ r: PulseTrainer.Result) -> String {
        let pct = Int((abs(r.driftBeats) * 100).rounded()), ms = Int((abs(r.driftSeconds) * 1000).rounded())
        if pct <= 2 { return "Right on the beat after \(r.measures) silent measures" }
        return "\(r.driftSeconds > 0 ? "Late" : "Early") by \(pct) % of a beat (\(ms) ms) after \(r.measures) silent measures"
    }

    static func tempoText(_ r: PulseTrainer.Result, clickBPM: Double) -> String {
        let change = r.tappedBPM / clickBPM - 1
        let trend = abs(change) < 0.02 ? "steady" : (change > 0 ? "sped up" : "slowed down")
        return "Your tempo \(Int(r.tappedBPM.rounded())) (click \(Int(clickBPM))) — \(trend)"
    }
}

private struct DriftNeedle: View {
    /// Fraction of a beat; the scale shows ±30 %.
    let drift: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = w / 2 + CGFloat(max(-0.3, min(0.3, drift)) / 0.3) * (w / 2)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 10)
                Rectangle().fill(Color.green.opacity(0.35)).frame(width: w * 0.05 / 0.3, height: 10)
                    .offset(x: w / 2 - w * 0.05 / 0.6)
                Rectangle().fill(Color.primary.opacity(0.6)).frame(width: 2, height: 22).offset(x: w / 2 - 1)
                Circle().fill(abs(drift) <= 0.05 ? Color.green : (abs(drift) <= 0.15 ? Color.orange : Color.red))
                    .frame(width: 20, height: 20).offset(x: x - 10)
            }
            .frame(height: 22)
        }
        .frame(width: 320, height: 22)
        .overlay(alignment: .bottom) {
            HStack { Text("early"); Spacer(); Text("late") }.font(.caption2).foregroundStyle(.secondary).offset(y: 16)
        }
        .padding(.bottom, 14)
    }
}

private struct PulseSummary: View {
    let runner: PulseTrainerRunner

    var body: some View {
        let results = runner.results
        VStack(spacing: 18) {
            Text("How the pulse held").font(.largeTitle.bold())
            Chart {
                RuleMark(y: .value("on the beat", 0)).foregroundStyle(.secondary)
                ForEach(results, id: \.cycle) { r in
                    LineMark(x: .value("silence", r.cycle + 1), y: .value("drift % of a beat", r.driftBeats * 100))
                    PointMark(x: .value("silence", r.cycle + 1), y: .value("drift % of a beat", r.driftBeats * 100))
                        .foregroundStyle(abs(r.driftBeats) <= 0.05 ? .green : (abs(r.driftBeats) <= 0.15 ? .orange : .red))
                        .annotation(position: .top) { Text("\(r.measures)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            .chartYAxisLabel("drift, % of a beat (+ late, − early)")
            .chartXAxisLabel("silence # (label: its length in measures)")
            .frame(maxWidth: 640, minHeight: 240)
            let late = results.filter { $0.driftBeats > 0.05 }.count, early = results.filter { $0.driftBeats < -0.05 }.count
            Text(late > early * 2 ? "You tend to slow down." : (early > late * 2 ? "You tend to rush." : "No strong tendency either way."))
                .font(.title3)
            Text("Longest silence held: \(results.filter { abs($0.driftBeats) <= 0.05 }.map(\.measures).max() ?? 0) measures")
                .foregroundStyle(.secondary)
            Button("Again") { runner.again() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }
}
