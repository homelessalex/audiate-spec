import SwiftUI

/// Placeholder home until M2.
struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 16) {
            if let error = model.loadError {
                Text("Failed to load resources: \(error)").foregroundStyle(.red)
            } else {
                Text("\(model.library?.patterns.count ?? 0) patterns loaded")
            }
            HStack {
                Button("Calibrate…") { openWindow(id: WindowID.calibration) }
                Button("Debug Player") { openWindow(id: WindowID.debug) }
                    .help("⇧⌘D")
            }
        }
        .padding(40)
    }
}
