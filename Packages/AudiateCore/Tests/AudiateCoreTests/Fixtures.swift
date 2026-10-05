import Foundation
import Testing
@testable import AudiateCore

/// Loads `data/*.json` straight from the repository so tests always run against the generated library.
enum Fixtures {
    static let dataDirectory: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // AudiateCoreTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // AudiateCore
        .deletingLastPathComponent() // Packages
        .deletingLastPathComponent() // repo root
        .appendingPathComponent("data")

    static let patternsJSON: Data = load("patterns.json")
    static let cellsJSON: Data = load("cells.json")

    static let library: PatternLibrary = {
        do { return try PatternLibrary(patternsJSON: patternsJSON, cellsJSON: cellsJSON) }
        catch { fatalError("library failed to load: \(error)") }
    }()

    /// The JSON as written by tools/build_patterns.py, decoded independently of AudiateCore.
    static let rawPatterns: [RawPattern] = {
        do { return try JSONDecoder().decode(RawPatternFile.self, from: patternsJSON).patterns }
        catch { fatalError("raw patterns failed to decode: \(error)") }
    }()

    static func pattern(_ id: String) -> Pattern {
        guard let p = library.pattern(id: id) else { fatalError("no pattern \(id)") }
        return p
    }

    private static func load(_ name: String) -> Data {
        let url = dataDirectory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { fatalError("missing \(url.path)") }
        return data
    }
}

struct RawPatternFile: Decodable {
    let version: Int
    let ticksPerMicrobeat: Int
    let patterns: [RawPattern]
}

struct RawPattern: Decodable, Sendable, CustomTestStringConvertible {
    let id: String
    let meter: String
    let content: String
    let timeSignature: String
    let macrobeats: [Int]
    let measureTicks: Int
    let pickupTicks: Int
    let difficulty: String
    let difficultyScore: Double
    let syllables: String
    let events: [RawEvent]

    var testDescription: String { id }
}

struct RawEvent: Decodable, Sendable {
    let startTick: Int
    let ticks: Int
    let kind: String
    let tieToNext: Bool
    let syllable: String
    let syllableDisplay: String
    let notation: RawNotation
    let isPickup: Bool
}

struct RawNotation: Decodable, Sendable {
    let value: String
    let dots: Int
    let tuplet: Int?
}
