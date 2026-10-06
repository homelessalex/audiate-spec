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

    @Test func duplesAndTriplesArePaired() {
        let groups = Dictionary(grouping: curriculum.units, by: \.group).mapValues { $0.map(\.id) }
        #expect(groups[1] == ["U1", "U2"])
        #expect(groups[2] == ["U3", "U4"])
        #expect(groups[3] == ["U5", "U6"])
        #expect(curriculum.previousGroup(of: "U3").map(\.id) == ["U1", "U2"])
        #expect(curriculum.previousGroup(of: "U1").isEmpty)
    }

    @Test func patternsAreOrderedEasyToDifficult() {
        for unit in curriculum.units {
            let levels = curriculum.patterns(of: unit, in: library).map(DifficultyScorer.level)
            #expect(levels == levels.sorted(), "\(unit.id)")
        }
    }
}
