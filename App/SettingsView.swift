import SwiftUI

/// ⌘, — session length, two-hand mode, tap sound, calibration, reset.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var confirmReset = false

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
            Section("Timing") {
                Button("Calibrate…") { openWindow(id: WindowID.calibration) }
            }
            Section("Progress") {
                Button("Show the introduction again") { settings.didShowIntroduction = false }
                Button("Reset progress…", role: .destructive) { confirmReset = true }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .confirmationDialog("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { model.resetProgress() }
        } message: {
            Text("Every attempt, review and passed level is deleted. Calibration is kept. This can't be undone.")
        }
    }
}
