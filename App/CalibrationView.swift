import AudiateAudio
import AudiateCore
import SwiftData
import SwiftUI

/// 16 clicks at 90 BPM; tap Space along; offset = median(tap − click) after the first 4.
struct CalibrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var recorder = TapRecorder()
    @State private var result: CalibrationResult?
    @State private var error: String?

    private var device: OutputDevice? { model.outputDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Output: \(device?.name ?? "unknown")").font(.headline)
            if device?.isBluetooth == true {
                Label("Bluetooth output adds 100–250 ms of latency. Use wired headphones or built-in speakers for accurate grading.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Text("Press Start, then tap together with every click — Space or the pad below, whichever you will use in exercises. The first four clicks are for settling in.")
            if let current = device.flatMap({ context.calibration(for: $0.uid) }) {
                Text("Current offset: \(current.inputOffsetMs, specifier: "%.0f") ms").foregroundStyle(.secondary)
            }

            HStack {
                Button(recorder.isRunning ? "Listening… (\(recorder.tapCount))" : "Start") { start() }
                    .disabled(recorder.isRunning || model.player == nil)
                    .keyboardShortcut(.return, modifiers: [])
            }

            TapPad(recorder: recorder)

            if let result {
                if result.isAccepted, let median = result.medianOffset {
                    Text("Saved: offset \(median * 1000, specifier: "%.0f") ms (spread \((result.iqr ?? 0) * 1000, specifier: "%.0f") ms)")
                        .foregroundStyle(.green)
                } else {
                    Text("Taps were too uneven (\(result.offsets.count) matched, spread \((result.iqr ?? 0) * 1000, specifier: "%.0f") ms). Please repeat.")
                        .foregroundStyle(.red)
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .padding(24)
        .frame(width: 440)
        .onDisappear { recorder.cancel() }
    }

    private func start() {
        guard let player = model.player else { return }
        result = nil
        error = nil
        let clicks = CalibrationPolicy.clickTimes
        let timeline = Timeline(
            sounds: clicks.enumerated().map { ScheduledSound(time: $0.element, sound: .click(accented: $0.offset % 4 == 0)) },
            responses: [], measureDuration: 4 * CalibrationPolicy.beat, duration: Double(clicks.count) * CalibrationPolicy.beat
        )
        do {
            try recorder.run(timeline, player: player, tapSound: false, keyMap: model.settings.keyMap) { taps in
                let r = CalibrationAnalyzer.analyze(clickTimes: clicks, taps: taps)
                result = r
                if r.isAccepted, let median = r.medianOffset, let uid = device?.uid {
                    context.saveCalibration(deviceUID: uid, inputOffset: median)
                }
            }
        } catch {
            self.error = "\(error)"
        }
    }
}
