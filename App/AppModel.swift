import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Loads the bundled library and samples and owns the single audio engine.
@MainActor
@Observable
final class AppModel {
    let library: PatternLibrary?
    let player: BlockPlayer?
    let loadError: String?

    init() {
        do {
            let (library, player) = try Self.load(from: .main)
            self.library = library
            self.player = player
            loadError = nil
        } catch {
            library = nil
            player = nil
            loadError = "\(error)"
        }
    }

    private static func load(from bundle: Bundle) throws -> (PatternLibrary, BlockPlayer) {
        guard let patterns = bundle.url(forResource: "patterns", withExtension: "json"),
              let cells = bundle.url(forResource: "cells", withExtension: "json"),
              let samples = bundle.url(forResource: "Samples", withExtension: nil) else {
            throw AppError.missingResource
        }
        let library = try PatternLibrary(patternsJSON: Data(contentsOf: patterns), cellsJSON: Data(contentsOf: cells))
        return (library, try BlockPlayer(bank: SampleBank.load(directory: samples)))
    }

    var outputDevice: OutputDevice? { OutputDevice.current() }
}

enum AppError: Error {
    case missingResource
}
