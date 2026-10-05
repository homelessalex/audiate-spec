import SwiftData
import SwiftUI

@main
struct AudiateApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .frame(minWidth: 720, minHeight: 560)
        }
        .modelContainer(model.container)

        Window("Calibration", id: WindowID.calibration) {
            CalibrationView()
                .environment(model)
        }
        .modelContainer(model.container)
        .windowResizability(.contentSize)

        Window("Debug Player", id: WindowID.debug) {
            DebugView()
                .environment(model)
        }
        .modelContainer(model.container)
        .keyboardShortcut("d", modifiers: [.command, .shift])
    }
}

/// Single-window app: closing the last window quits instead of leaving it alive in the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
