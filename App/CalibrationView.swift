import AudiateAudio
import AudiateCore
import SwiftData
import SwiftUI

/// 16 clicks at 90 BPM; tap Space along; offset = median(tap − click) after the first 4.
/// Taps on a MIDI keyboard calibrate the MIDI offset, kept apart from the computer keys'.
struct CalibrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @State private var recorder = TapRecorder()
    @State private var result: CalibrationResult?
    @State private var error: String?
    /// The source the last run measured.
    @State private var source = InputSource.computer

    @State private var midi = MIDIInput.shared

    private var device: OutputDevice? { model.outputDevice }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Output: \(device?.name ?? "unknown")").font(.headline)
            if device?.isBluetooth == true {
                Label("Bluetooth output adds 100–250 ms of latency. Use wired headphones or built-in speakers for accurate grading.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Text("Press Start, then tap together with every click — Space, the pad below or a MIDI key, whichever you will use in exercises. The first four clicks are for settling in.")
            if midi.isConnected {
                Text("A MIDI keyboard has its own offset: if you play exercises on it, calibrate once with it too.")
                    .foregroundStyle(.secondary)
            }
            ForEach(InputSource.allCases, id: \.self) { source in
                if let current = device.flatMap({ context.calibration(for: $0.uid, source: source) }) {
                    Text("Current offset\(source == .midi ? " (MIDI)" : ""): \(current.inputOffsetMs, specifier: "%.0f") ms")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(recorder.isRunning ? "Listening… (\(recorder.tapCount))" : "Start") { start() }
                    .disabled(recorder.isRunning || model.player == nil)
                    .keyboardShortcut(.return, modifiers: [])
            }

            TapPad(recorder: recorder)

            if let result {
                if result.isAccepted, let median = result.medianOffset {
                    Text("Saved\(source == .midi ? " for MIDI" : ""): offset \(median * 1000, specifier: "%.0f") ms (spread \((result.iqr ?? 0) * 1000, specifier: "%.0f") ms)")
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
            sounds: clicks.enumerated().map { ScheduledSound(time: $0.element, sound: $0.offset % 4 == 0 ? .downbeat : .click(accented: true)) },
            responses: [], measureDuration: 4 * CalibrationPolicy.beat, duration: Double(clicks.count) * CalibrationPolicy.beat
        )
        do {
            try recorder.run(timeline, player: player, setup: TapSetup(keyMap: model.settings.keyMap, tapSound: false)) { _ in
                // measure whichever source most taps came from, and only its taps
                let sources = recorder.tapSources
                source = sources.filter { $0 == .midi }.count * 2 > sources.count ? .midi : .computer
                let taps = zip(recorder.taps, sources).filter { $0.1 == source }.map(\.0)
                let r = CalibrationAnalyzer.analyze(clickTimes: clicks, taps: taps)
                result = r
                if r.isAccepted, let median = r.medianOffset, let uid = device?.uid {
                    context.saveCalibration(deviceUID: uid, source: source, inputOffset: median)
                }
            }
        } catch {
            self.error = "\(error)"
        }
    }
}
