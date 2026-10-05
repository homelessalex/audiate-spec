import Testing
@testable import AudiateCore

@Suite("Curriculum")
struct CurriculumTests {
    let curriculum = Fixtures.curriculum
    let library = Fixtures.library

    @Test func twelveUnitsCoverEveryPatternExactlyOnce() {
        #expect(curriculum.units.map(\.id) == (1...12).map { "U\($0)" })
        for pattern in library.patterns {
            #expect(curriculum.units.filter { $0.contains(patternID: pattern.id) }.count == 1, "\(pattern.id)")
        }
    }

    @Test func unitMetersMatchTheirPatterns() {
        for unit in curriculum.units {
            let patterns = curriculum.patterns(of: unit, in: library)
            #expect(!patterns.isEmpty, "\(unit.id)")
            #expect(Set(patterns.map(\.meter.id)) == Set(unit.meters), "\(unit.id)")
        }
    }

    @Test func patternsAreOrderedEasyToDifficult() {
        for unit in curriculum.units {
            let levels = curriculum.patterns(of: unit, in: library).map(DifficultyScorer.level)
            #expect(levels == levels.sorted(), "\(unit.id)")
        }
    }
}
