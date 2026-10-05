import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let error = model.loadError {
            Text("Failed to load resources: \(error)").foregroundStyle(.red).padding()
        } else if let session = model.session {
            SessionView(runner: session)
        } else {
            HomeView()
        }
    }
}
