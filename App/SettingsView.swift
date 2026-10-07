import AudiateAudio
import SwiftUI

/// ⌘, — session length, two-hand mode, tap sound, calibration, reset.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var confirmReset = false
    @State private var capture = KeyCapture()
    @State private var capturing: KeyRole?
    @State private var keyMessage: String?
    @State private var midi = MIDIInput.shared
    @State private var learnToken: UInt64?

    enum KeyRole { case addRhythm, replacePulse }

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section("Practice") {
                Stepper("Session length: \(settings.sessionMinutes) min", value: $settings.sessionMinutes, in: 5...30, step: 1)
                Toggle(isOn: $settings.twoHandMode) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Two hands")
                        Text("Left hand (F) taps every beat all the time, right hand (J, Space or the pad) plays the rhythm. Both are graded — like a foot keeping time under the hands.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle("Tap sound", isOn: $settings.tapSound)
            }
            Section("Keys") {
                LabeledContent("Rhythm") {
                    HStack {
                        ForEach(settings.keyMap.rhythm, id: \.self) { key in
                            KeyChip(label: key.label, removable: settings.keyMap.rhythm.count > 1) {
                                settings.keyMap.rhythm.removeAll { $0 == key }
                            }
                        }
                        Button(capturing == .addRhythm ? "Press a key…" : "Add…") { startCapture(.addRhythm) }
                    }
                }
                LabeledContent("Pulse (left hand, two-hand mode)") {
                    HStack {
                        ForEach(settings.keyMap.pulse, id: \.self) { KeyChip(label: $0.label, removable: false) {} }
                        Button(capturing == .replacePulse ? "Press a key…" : "Change…") { startCapture(.replacePulse) }
                    }
                }
                if let keyMessage { Text(keyMessage).font(.caption).foregroundStyle(.orange) }
                Button("Restore defaults (Space, J · F)") { settings.keyMap = .standard }
            }
            Section("MIDI keyboard") {
                LabeledContent("Connected") {
                    Text(midi.sourceNames.isEmpty ? "None" : midi.sourceNames.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
                if let error = midi.error { Text(error).font(.caption).foregroundStyle(.orange) }
                LabeledContent("Two-hand split") {
                    HStack {
                        KeyChip(label: "pulse < \(MIDINote.name(settings.midiSplit.lowestRhythmNote)) ≤ rhythm", removable: false) {}
                        Button(learnToken == nil ? "Learn…" : "Press the lowest rhythm key…") { learnSplit() }
                    }
                }
                Text("With one hand any key or pad taps the rhythm. With two hands the keys below the split keep the beat and the rest play the rhythm. Calibrate once on the MIDI keyboard too — it has its own offset.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Timing") {
                Button("Calibrate…") { openWindow(id: WindowID.calibration) }
            }
            Section("Progress") {
                Button("Show the introduction again") { settings.didShowIntroduction = false }
                Button("Reset progress…", role: .destructive) { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            capture.cancel()
            stopLearning()
        }
        .frame(width: 460)
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetProgress() }
        } message: {
            Text("Every attempt, review and passed level is deleted. Calibration is kept. This can't be undone.")
        }
    }

    private func learnSplit() {
        guard learnToken == nil else { return stopLearning() }
        learnToken = midi.addListener { note in
            model.settings.midiSplit = MIDISplit(lowestRhythmNote: note.note)
            stopLearning()
        }
    }

    private func stopLearning() {
        if let learnToken { midi.removeListener(learnToken) }
        learnToken = nil
    }

    private func startCapture(_ role: KeyRole) {
        keyMessage = nil
        capturing = role
        capture.capture { key in
            capturing = nil
            let settings = model.settings
            guard KeyMap.isAllowed(key.keyCode) else {
                keyMessage = "\(key.label) is used by the app (numbers answer, Return continues, Esc pauses, arrows/Delete write). Pick another key."
                return
            }
            var map = settings.keyMap
            map.rhythm.removeAll { $0.keyCode == key.keyCode }
            map.pulse.removeAll { $0.keyCode == key.keyCode }
            switch role {
            case .addRhythm: map.rhythm.append(key)
            case .replacePulse: map.pulse = [key]
            }
            if map.rhythm.isEmpty { map.rhythm = KeyMap.standard.rhythm.filter { $0.keyCode != key.keyCode } }
            settings.keyMap = map
        }
    }
}

private struct KeyChip: View {
    let label: String
    let removable: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.callout.monospaced())
            if removable {
                Button { remove() } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.15)))
    }
}
