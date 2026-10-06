import Testing
@testable import AudiateCore

@Suite("Gate")
struct GateTests {
    let curriculum = Fixtures.curriculum

    func keys(_ s: String) -> Set<LevelKey> {
        Set(s.split(separator: " ").map { token in
            let parts = token.split(separator: ":")
            return LevelKey(unitID: String(parts[0]), level: SkillLevel(rawValue: String(parts[1]))!)
        })
    }

    func unlocked(_ key: String, passed: String) -> Bool {
        Gate.isUnlocked(keys(key).first!, curriculum: curriculum, passed: keys(passed))
    }

    @Test(arguments: [
        ("U1:AO", "", true),
        ("U1:VA", "", false),
        ("U1:VA", "U1:AO", true),
        ("U2:AO", "", true),                                   // duple and triple together
        ("U3:AO", "U1:AO U1:VA", false),                       // the whole previous group must pass VA
        ("U3:AO", "U1:AO U1:VA U2:AO U2:VA", true),
        ("U4:AO", "U1:AO U1:VA U2:AO U2:VA", true),
        ("U7:AO", "U5:VA", false),
        ("U7:AO", "U5:VA U6:VA", true),
        ("U1:PS", "U1:AO U1:VA", false),                       // needs a second meter
        ("U1:PS", "U1:AO U1:VA U2:AO U2:VA", true),
        ("U3:PS", "U1:AO U1:VA U3:AO U3:VA", false),           // U1 and U3 are both duple
        ("U1:SA", "U1:AO", false),                             // reading after notation association
        ("U1:SA", "U1:AO U1:VA", true),
        ("U1:CS", "U1:SA", true),
        ("U1:GA", "U1:VA", false),
        ("U1:GA", "U1:VA U1:SA", true),
        ("U1:GV", "U1:VA U1:SA", true),
        ("U1:GS", "U1:CS", false),
        ("U1:GS", "U1:CS U1:GV", true),
        ("U1:IA", "U1:GV", true),
        ("U1:IS", "U1:GS", false),
        ("U1:IS", "U1:GS U1:IA", true),
        ("U12:AO", "U11:VA", true),
    ])
    func unlockRules(key: String, passed: String, expected: Bool) {
        #expect(unlocked(key, passed: passed) == expected)
    }

    @Test func passedLevelsStayPassedAndStatusesFollow() {
        let passed = keys("U1:SA")
        #expect(Gate.status(of: keys("U1:SA").first!, curriculum: curriculum, passed: passed, started: []) == .passed)
        #expect(Gate.status(of: keys("U1:AO").first!, curriculum: curriculum, passed: [], started: []) == .available)
        #expect(Gate.status(of: keys("U1:AO").first!, curriculum: curriculum, passed: [], started: keys("U1:AO")) == .inProgress)
        #expect(Gate.status(of: keys("U1:VA").first!, curriculum: curriculum, passed: [], started: []) == .locked)
    }

    /// Sound before sight: a unit's notation only after it passed AO by ear.
    @Test func notationOnlyAfterTheEarLevel() {
        #expect(!Gate.canShowNotation(unitID: "U1", passed: []))
        #expect(Gate.canShowNotation(unitID: "U1", passed: keys("U1:AO")))
        #expect(!Gate.canShowNotation(unitID: "U2", passed: keys("U1:AO U1:VA")))
    }

    @Test func theoryTrackOpensAfterU4CompositeSynthesis() {
        #expect(!Gate.isTheoryUnlocked(passed: keys("U4:SA")))
        #expect(Gate.isTheoryUnlocked(passed: keys("U4:CS")))
    }
}
