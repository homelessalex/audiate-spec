import AudiateCore
import SwiftUI

/// Placeholder until M2: confirms the bundled library loads through AudiateCore.
struct ContentView: View {
    private let status: String = {
        guard let patterns = Bundle.main.url(forResource: "patterns", withExtension: "json"),
              let cells = Bundle.main.url(forResource: "cells", withExtension: "json") else {
            return "Pattern library missing from bundle"
        }
        do {
            let library = try PatternLibrary(patternsJSON: Data(contentsOf: patterns), cellsJSON: Data(contentsOf: cells))
            return "\(library.patterns.count) patterns loaded"
        } catch {
            return "Pattern library failed to load: \(error)"
        }
    }()

    var body: some View {
        Text(status)
            .padding(40)
    }
}
