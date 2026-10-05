import Foundation
import Testing
@testable import AudiateCore

@Suite("Mastery and review")
struct MasteryAndReviewTests {
    let calendar = Fixtures.calendar
    let key = LevelKey(unitID: "U1", level: .aural)
    let ids = ["A", "B"]

    func attempt(_ id: String, day: Int, passed: Bool = true, accuracy: Double = 1, mode: PracticeMode = .evaluation,
                 level: SkillLevel = .aural, hour: Int = 12) -> Attempt {
        Attempt(date: Fixtures.day(day, hour: hour), unitID: "U1", level: level, patternID: id, exercise: .echo,
                mode: mode, passed: passed, accuracy: accuracy)
    }

    func isPassed(_ attempts: [Attempt]) -> Bool {
        MasteryEvaluator.isPassed(key, patternIDs: ids, attempts: attempts, calendar: calendar)
    }

    @Test func needsTwoPassesOnTwoDaysForEveryPattern() {
        let sameDay = ids.flatMap { [attempt($0, day: 0, hour: 9), attempt($0, day: 0, hour: 20)] }
        #expect(!isPassed(sameDay))
        let twoDays = ids.flatMap { [attempt($0, day: 0), attempt($0, day: 1)] }
        #expect(isPassed(twoDays))
        #expect(!isPassed(twoDays.filter { $0.patternID == "A" }))
    }

    @Test func teachingAttemptsDoNotCount() {
        #expect(!isPassed(ids.flatMap { [attempt($0, day: 0, mode: .teaching), attempt($0, day: 1, mode: .teaching)] }))
    }

    @Test func rollingAccuracyOfLastTwelveMustReach85Percent() {
        let passes = ids.flatMap { [attempt($0, day: 0), attempt($0, day: 1)] }
        let poor = (0..<12).map { attempt("A", day: 2, passed: false, accuracy: 0.5, hour: 1 + $0) }
        #expect(!isPassed(passes + poor))
        let recovered = passes + poor + (0..<12).map { attempt("B", day: 3, hour: 1 + $0) }
        #expect(isPassed(recovered))
    }

    @Test func inferenceLevelsNeedFifteenAttemptsOnTwoDays() {
        let gv = LevelKey(unitID: "U1", level: .generalizationVerbal)
        func run(_ attempts: [Attempt]) -> Bool { MasteryEvaluator.isPassed(gv, patternIDs: [], attempts: attempts, calendar: calendar) }
        let make = { (day: Int, n: Int, acc: Double) in
            (0..<n).map { Attempt(date: Fixtures.day(day, hour: $0 % 24), unitID: "U1", level: .generalizationVerbal, patternID: nil,
                                  exercise: .nameSyllables, mode: .evaluation, passed: acc > 0.5, accuracy: acc) }
        }
        #expect(!run(make(0, 20, 1)))
        #expect(run(make(0, 8, 1) + make(1, 7, 1)))
        #expect(!run(make(0, 8, 0.7) + make(1, 7, 0.7)))
    }

    @Test func leitnerBoxesAndIntervals() {
        let item = ItemKey(subject: "A", level: .aural)
        var state: ItemState?
        var dues: [Int] = []
        for _ in 0..<7 {
            state = LeitnerScheduler.update(state, key: item, passed: true, date: Fixtures.day(0), calendar: calendar)
            dues.append(calendar.dateComponents([.day], from: calendar.startOfDay(for: Fixtures.day(0)), to: state!.dueDate).day!)
        }
        #expect(dues == [1, 2, 4, 8, 16, 32, 32])
        state = LeitnerScheduler.update(state, key: item, passed: false, date: Fixtures.day(0), calendar: calendar)
        #expect(state?.box == 1)
        #expect(state?.consecutiveFails == 1)
    }

    @Test func dueItemsOldestFirst() {
        let a = ItemState(key: ItemKey(subject: "A", level: .aural), box: 1, dueDate: Fixtures.day(2), consecutiveFails: 0)
        let b = ItemState(key: ItemKey(subject: "B", level: .aural), box: 1, dueDate: Fixtures.day(1), consecutiveFails: 0)
        let c = ItemState(key: ItemKey(subject: "C", level: .aural), box: 1, dueDate: Fixtures.day(5), consecutiveFails: 0)
        #expect(LeitnerScheduler.due([a, b, c], on: Fixtures.day(3)).map(\.key.subject) == ["B", "A"])
    }

    @Test(arguments: [
        (SkillLevel.symbolic, SkillLevel?.some(.verbal)),
        (.compositeSynthesis, .verbal),
        (.generalizationAural, .aural),
        (.generalizationVerbal, .verbal),
        (.aural, nil),
        (.verbal, nil),
    ])
    func bridgingAfterTwoFails(level: SkillLevel, bridge: SkillLevel?) {
        let item = ItemKey(subject: "D-EL-03", level: level)
        let once = LeitnerScheduler.update(nil, key: item, passed: false, date: Fixtures.day(0), calendar: calendar)
        #expect(LeitnerScheduler.bridge(for: once) == nil)
        let twice = LeitnerScheduler.update(once, key: item, passed: false, date: Fixtures.day(0), calendar: calendar)
        #expect(LeitnerScheduler.bridge(for: twice)?.level == bridge)
    }

    @Test func recordingTwoSymbolicFailsSchedulesAVerbalBridgeForTomorrow() {
        var progress = LearnerProgress()
        for hour in [10, 11] {
            progress.record(Attempt(date: Fixtures.day(0, hour: hour), unitID: "U5", level: .symbolic, patternID: "D-EL-03",
                                    exercise: .read, mode: .evaluation, passed: false, accuracy: 0.3),
                            curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        }
        let bridge = progress.items[ItemKey(subject: "D-EL-03", level: .verbal)]
        #expect(bridge?.dueDate == calendar.startOfDay(for: Fixtures.day(1)))
    }
}
