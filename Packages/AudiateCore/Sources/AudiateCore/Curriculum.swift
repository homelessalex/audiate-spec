import Foundation

/// Ordered content units.
public struct Curriculum: Sendable {
    public let units: [CurriculumUnit]

    public init(units: [CurriculumUnit]) {
        self.units = units
    }

    public init(json: Data) throws {
        struct File: Decodable { let units: [CurriculumUnit] }
        self.init(units: try JSONDecoder().decode(File.self, from: json).units)
    }

    public func unit(id: String) -> CurriculumUnit? { units.first { $0.id == id } }

    public func index(of unitID: String) -> Int? { units.firstIndex { $0.id == unitID } }

    public func unit(containing patternID: String) -> CurriculumUnit? { units.first { $0.contains(patternID: patternID) } }

    /// The unit's patterns, easy → difficult, then library order (docs/03-rhythm-model.md §6).
    public func patterns(of unit: CurriculumUnit, in library: PatternLibrary) -> [Pattern] {
        let patterns = library.patterns(idPrefixes: unit.patternIdPrefixes)
        return patterns.enumerated()
            .sorted { (DifficultyScorer.level($0.element), $0.offset) < (DifficultyScorer.level($1.element), $1.offset) }
            .map(\.element)
    }

    public var allLevelKeys: [LevelKey] {
        units.flatMap { unit in SkillLevel.allCases.map { LevelKey(unitID: unit.id, level: $0) } }
    }
}
