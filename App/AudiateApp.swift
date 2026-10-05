import SwiftData
import SwiftUI

@main
struct AudiateApp: App {
    @State private var model = AppModel()
    private let container: ModelContainer = {
        do { return try ModelContainer(for: CalibrationProfile.self) }
        catch { fatalError("SwiftData container: \(error)") }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .modelContainer(container)

        Window("Calibration", id: WindowID.calibration) {
            CalibrationView()
                .environment(model)
        }
        .modelContainer(container)
        .windowResizability(.contentSize)

        Window("Debug Player", id: WindowID.debug) {
            DebugView()
                .environment(model)
        }
        .modelContainer(container)
        .keyboardShortcut("d", modifiers: [.command, .shift])
    }
}
