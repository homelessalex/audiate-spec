// Decoding shapes of data/patterns.json and data/cells.json.
// Stored syllables, notation and difficulty are deliberately not decoded: AudiateCore derives them.

struct PatternFileDTO: Decodable {
    let ticksPerMicrobeat: Int
    let meters: [String: MeterDTO]
    let patterns: [PatternDTO]
}

struct MeterDTO: Decodable {
    let macro: [Int]
    let notation: String
    let allowThirds: Bool
}

struct PatternDTO: Decodable {
    let id: String
    let meter: String
    let content: ContentKind
    let pickupTicks: Int
    let events: [EventDTO]
}

struct EventDTO: Decodable {
    let startTick: Int
    let ticks: Int
    let kind: EventKind
    let tieToNext: Bool
}

struct CellFileDTO: Decodable {
    let ticksPerMicrobeat: Int
    let cells: [String: [CellDTO]]
}

struct CellDTO: Decodable {
    let tokens: String
    let minContent: ContentKind
}
