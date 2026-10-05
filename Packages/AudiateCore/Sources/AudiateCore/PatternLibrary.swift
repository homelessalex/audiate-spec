import Foundation

/// The familiar-pattern library and generator cells, loaded from data/patterns.json and data/cells.json.
public struct PatternLibrary: Sendable {
    public let meters: [String: Meter]
    /// In file order (which is teaching order within a unit).
    public let patterns: [Pattern]
    private let cellsBySize: [Int: [Cell]]
    private let byID: [String: Pattern]
    private let familiarShapes: Set<RhythmShape>

    public init(patternsJSON: Data, cellsJSON: Data, deriver: SyllableDeriver = SyllableDeriver()) throws {
        let decoder = JSONDecoder()
        let file = try decoder.decode(PatternFileDTO.self, from: patternsJSON)
        let cellFile = try decoder.decode(CellFileDTO.self, from: cellsJSON)
        for tpm in [file.ticksPerMicrobeat, cellFile.ticksPerMicrobeat] where tpm != Rhythm.ticksPerMicrobeat {
            throw RhythmError.unsupportedTicksPerMicrobeat(tpm)
        }

        var meters: [String: Meter] = [:]
        for (id, dto) in file.meters {
            meters[id] = Meter(id: id, macrobeats: dto.macro, allowsThirds: dto.allowThirds,
                               timeSignature: try TimeSignature(dto.notation))
        }

        let patterns = try file.patterns.map { dto in
            guard let meter = meters[dto.meter] else { throw RhythmError.unknownMeter(dto.meter) }
            let events = dto.events.map {
                RhythmEvent(startTick: $0.startTick, ticks: $0.ticks, kind: $0.kind, tieToNext: $0.tieToNext)
            }
            let pattern = Pattern(id: dto.id, meter: meter, content: dto.content,
                                  pickupTicks: dto.pickupTicks, events: events)
            try PatternValidator.validate(pattern, deriver: deriver)
            return pattern
        }

        var cellsBySize: [Int: [Cell]] = [:]
        for (key, dtos) in cellFile.cells {
            guard let size = Int(key) else { throw RhythmError.invalidToken(key) }
            cellsBySize[size] = try dtos.map { dto in
                let cell = Cell(macrobeatSize: size, tokens: try RhythmToken.parse(dto.tokens), minContent: dto.minContent)
                guard cell.ticks == size * Rhythm.ticksPerMicrobeat else {
                    throw RhythmError.cellLengthMismatch(tokens: dto.tokens, macrobeatSize: size)
                }
                return cell
            }
        }

        self.meters = meters
        self.patterns = patterns
        self.cellsBySize = cellsBySize
        self.byID = Dictionary(uniqueKeysWithValues: patterns.map { ($0.id, $0) })
        self.familiarShapes = Set(patterns.map(\.shape))
    }

    public func pattern(id: String) -> Pattern? { byID[id] }

    public func patterns(meterID: String) -> [Pattern] { patterns.filter { $0.meter.id == meterID } }

    public func patterns(content: ContentKind) -> [Pattern] { patterns.filter { $0.content == content } }

    /// Units are defined by id prefixes (docs/02-curriculum.md §1), e.g. `["D-RS-", "T-RS-"]`.
    public func patterns(idPrefixes: [String]) -> [Pattern] {
        patterns.filter { p in idPrefixes.contains { p.id.hasPrefix($0) } }
    }

    public func cells(forMacrobeatSize size: Int) -> [Cell] { cellsBySize[size] ?? [] }

    /// True if a library pattern sounds exactly like `shape`.
    public func isFamiliar(_ shape: RhythmShape) -> Bool { familiarShapes.contains(shape) }
}
