import Foundation
import Testing
@testable import AudiateCore

@Suite("Phrase reading (E13)")
struct PhraseTests {
    let calendar = Fixtures.calendar

    func attempt(rung: Int, passed: Bool, mode: PracticeMode = .evaluation, day: Int = 0) -> Attempt {
        Attempt(date: Fixtures.day(day), unitID: PhrasePolicy.unitID, level: .compositeSynthesis,
                patternID: PhraseLadder.patternID(rung: rung), exercise: .readPhrase, mode: mode, passed: passed, accuracy: passed ? 1 : 0)
    }

    // MARK: Ladder

    @Test func ladderClimbsAfterThreePassesInARow() {
        #expect(PhraseLadder.rung(after: []) == 0)
        #expect(PhraseLadder.rung(after: [true, true].map { attempt(rung: 0, passed: $0) }) == 0)
        #expect(PhraseLadder.rung(after: [true, true, true].map { attempt(rung: 0, passed: $0) }) == 1)
        // a miss in between restarts the count
        #expect(PhraseLadder.rung(after: [true, true, false, true, true].map { attempt(rung: 0, passed: $0) }) == 0)
    }

    @Test func ladderStepsBackAfterTwoMissesInARow() {
        let up = [true, true, true].map { attempt(rung: 0, passed: $0) }
        #expect(PhraseLadder.rung(after: up + [attempt(rung: 1, passed: false)]) == 1)
        #expect(PhraseLadder.rung(after: up + [false, false].map { attempt(rung: 1, passed: $0) }) == 0)
        // never below the first rung
        #expect(PhraseLadder.rung(after: [false, false, false].map { attempt(rung: 0, passed: $0) }) == 0)
    }

    @Test func ladderIgnoresCorrectionsAndStaleRungs() {
        let up = [true, true, true].map { attempt(rung: 0, passed: $0) }
        // corrections are practice; attempts planned at the old rung finish the step without moving the ladder
        let rest = [attempt(rung: 1, passed: false, mode: .practice), attempt(rung: 0, passed: false), attempt(rung: 0, passed: false)]
        #expect(PhraseLadder.rung(after: up + rest) == 1)
    }

    @Test func ladderTopsOut() {
        var attempts: [Attempt] = []
        for rung in PhrasePolicy.rungs.indices { attempts += (0..<5).map { _ in attempt(rung: rung, passed: true) } }
        #expect(PhraseLadder.rung(after: attempts) == PhrasePolicy.rungs.count - 1)
        #expect(PhrasePolicy.rungs.first == .init(measures: 2, tempoFactor: 0.85))
        #expect(PhrasePolicy.rungs.last == .init(measures: 4, tempoFactor: 1.0))
    }

    @Test func tempoNeverBelowTheMetersRange() {
        for meter in Fixtures.library.meters.values {
            for rung in PhrasePolicy.rungs {
                let tempo = PhrasePolicy.tempo(for: rung, meter: meter)
                #expect(tempo.bpm >= TempoPolicy.range(for: meter).lowerBound, "\(meter.id) \(rung)")
                #expect(tempo.bpm <= Tempo.standard(for: meter).bpm)
            }
        }
        // the slowest triple phrase: 56 × 0.85 = 48 (no longer 39)
        #expect(PhrasePolicy.tempo(for: PhrasePolicy.rungs[0], meter: Fixtures.library.meters["usual_triple"]!).bpm == 48)
    }

    // MARK: Phrase content

    @Test func phraseNeverRepeatsAPatternBackToBack() {
        let pool = ["D-MM-01", "D-MM-02", "D-DV-01"].map(Fixtures.pattern)
        var rng = SeededRandomNumberGenerator(seed: 3)
        for _ in 0..<50 {
            let phrase = PhraseSpec.phrase(from: pool, measures: 4, using: &rng)!
            #expect(phrase.count == 4)
            #expect(zip(phrase, phrase.dropFirst()).allSatisfy { $0.id != $1.id })
        }
        #expect(PhraseSpec.phrase(from: [], measures: 2, using: &rng) == nil)
    }

    // MARK: Timeline and grading

    let phrase = ["D-MM-02", "D-DV-01"].map(Fixtures.pattern)
    let tempo = Tempo(bpm: 56)

    @Test func timelineLooksThenReadsMeasureAfterMeasure() throws {
        let t = try Timeline.phraseBlock(patterns: phrase, tempo: tempo, clickStage: .b)
        #expect(t.measureRoles == [.countIn, .prompt(0), .hold(0), .response(0), .response(1)])
        #expect(t.responses.count == 2)
        #expect(abs(t.responses[1].start - t.responses[0].end) < 1e-9)
        #expect(abs(t.responses[0].start - 3 * t.measureDuration) < 1e-9)
        #expect(!t.sounds.contains { $0.sound == .hiHat }) // reading: only the click
        // stage B: the macrobeat click goes on through the phrase
        #expect(t.sounds.contains { $0.time >= t.responses[1].start })
    }

    @Test func pickupPatternsAreRefused() throws {
        guard let upbeat = Fixtures.library.patterns.first(where: { $0.pickupTicks > 0 }) else { return }
        #expect(throws: TimelineError.pickupInPhrase) {
            try Timeline.phraseBlock(patterns: [upbeat, upbeat], tempo: tempo, clickStage: .b)
        }
    }

    func grade(_ taps: (Timeline) -> [Double]) throws -> PhraseGrade {
        let t = try Timeline.phraseBlock(patterns: phrase, tempo: tempo, clickStage: .b)
        return PhraseGrade.grade(slots: t.responses, taps: taps(t), pulseTaps: nil, mode: .absolute)
    }

    @Test func everyMeasureMustPass() throws {
        let right = try grade { $0.responses.flatMap(\.expectedOnsets) }
        #expect(right.passed)
        #expect(right.firstFailing == nil)
        // the second measure's last note missing: the phrase fails at measure 2
        let missed = try grade { Array($0.responses.flatMap(\.expectedOnsets).dropLast()) }
        #expect(!missed.passed)
        #expect(missed.measurePassed(0))
        #expect(missed.firstFailing == 1)
    }

    @Test func aTapEarlyForTheNextMeasureCountsThere() throws {
        // the second measure's downbeat played 30 ms early, still inside the first measure
        let g = try grade { t in
            var taps = t.responses.flatMap(\.expectedOnsets)
            let i = t.responses[0].expectedOnsets.count
            taps[i] -= 0.03
            return taps
        }
        #expect(g.passed)
        #expect(g.rhythm[0].extras.isEmpty)
    }

    // MARK: Flow and planner

    @Test func flowReadsTheWholePhraseWithoutStopping() {
        let spec = PhraseSpec(phrases: [phrase], rung: 0, meterID: phrase[0].meter.id, tempo: tempo)
        let flow = FlowSequencer(steps: [.readPhrase(spec)], library: Fixtures.library)
        let a = flow.attempts[0]
        #expect(a.kind == .readPhrase)
        #expect(!a.kind.awaitsInput)
        #expect(a.phrase.map(\.id) == phrase.map(\.id))
        #expect(a.measureSlots.count == 2)
        #expect(a.response?.start == a.measureSlots[0].start)
        #expect(a.response?.end == a.measureSlots[1].end)
        #expect(a.item.patternID == PhraseLadder.patternID(rung: 0))
    }

    /// The review stays for measures while the click goes on; the last of them is the next lead-in.
    @Test(arguments: [(true, PhrasePolicy.passedReviewMeasures), (false, PhrasePolicy.missedReviewMeasures)])
    func reviewIsHeldForMeasures(passed: Bool, count: Int) {
        let spec = PhraseSpec(phrases: [phrase, phrase.reversed()], rung: 0, meterID: phrase[0].meter.id, tempo: tempo)
        var flow = FlowSequencer(steps: [.readPhrase(spec)], library: Fixtures.library)
        let a = flow.attempts[0]
        flow.report(passed: passed, forAttempt: 0)
        #expect(flow.endTime == nil)
        let after = flow.measures.filter { $0.start >= a.end - 1e-9 && $0.start < flow.attempts[1].start + 1e-9 }
        #expect(after.map(\.role) == Array(repeating: .review, count: count - 1) + [.leadIn])
        for m in after { #expect(flow.reviewed(in: m)?.index == 0) }
        // the click goes on through the review
        let review = after[0]
        #expect(!flow.sounds(from: review.start, to: review.end).isEmpty)
        // a miss brings the same phrase again, a pass the next one
        let next = flow.attempts[1]
        #expect(next.phrase.map(\.id) == (passed ? phrase.reversed() : phrase).map(\.id))
        #expect(abs(next.start - (a.end + Double(count - 1) * a.measureDuration)) < 1e-9)
    }

    /// One even click: after the stream's count-in every measure — look, phrase, review, lead-in — clicks
    /// the macrobeats only, so the click never thickens or thins out.
    @Test func clickStaysEvenAcrossPhrases() {
        let spec = PhraseSpec(phrases: [phrase, phrase, phrase], rung: 0, meterID: phrase[0].meter.id, tempo: tempo)
        var flow = FlowSequencer(steps: [.readPhrase(spec)], library: Fixtures.library)
        var results = [false, true, true, true]
        while let i = flow.awaiting, !results.isEmpty { flow.report(passed: results.removeFirst(), forAttempt: i) }
        let meter = phrase[0].meter
        let macrobeats = meter.macrobeatSpans.map { tempo.seconds(forTicks: $0.startTick, in: meter) }
        let d = flow.attempts[0].measureDuration
        for m in flow.measures where m.role != .countIn {
            // measure boundaries are sums of floats: compare with a little slack
            let clicks = flow.sounds(from: m.start - 1e-6, to: m.start + d - 1e-6).map { $0.time - m.start }
            #expect(clicks.count == macrobeats.count, "\(m.role) at \(m.start / d)")
            #expect(zip(clicks.sorted(), macrobeats).allSatisfy { abs($0 - $1) < 1e-6 })
        }
    }

    func progress(passingCSOf units: [String]) -> LearnerProgress {
        var passedAt: [LevelKey: Date] = [:]
        for unit in Fixtures.curriculum.units {
            for level in SkillLevel.allCases where level <= .compositeSynthesis {
                if units.contains(unit.id) || level <= .verbal && ["U1", "U2"].contains(unit.id) {
                    passedAt[LevelKey(unitID: unit.id, level: level)] = Fixtures.day(0)
                }
            }
        }
        let heard = units.flatMap { Fixtures.curriculum.patterns(of: Fixtures.curriculum.unit(id: $0)!, in: Fixtures.library) }.map {
            Attempt(date: Fixtures.day(0), unitID: Fixtures.curriculum.unit(containing: $0.id)!.id, level: .aural, patternID: $0.id,
                    exercise: .echo, mode: .teaching, passed: true, accuracy: 1)
        }
        return LearnerProgress(attempts: heard, passedAt: passedAt)
    }

    func phraseSteps(_ p: LearnerProgress, seed: UInt64 = 1, day: Int = 1) -> [PhraseSpec] {
        var rng = SeededRandomNumberGenerator(seed: seed)
        let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        return planner.plan(p, date: Fixtures.day(day), using: &rng).steps.compactMap { if case .readPhrase(let s) = $0 { s } else { nil } }
    }

    @Test func noPhrasesBeforeAUnitPassedCS() {
        #expect(phraseSteps(progress(passingCSOf: [])).isEmpty)
    }

    @Test func phrasesMixUnitsPastCSAtTheLadderRung() {
        let p = progress(passingCSOf: ["U1", "U3", "U9"])
        for seed in 1...10 as ClosedRange<UInt64> {
            let steps = phraseSteps(p, seed: seed)
            #expect(steps.count == 1)
            guard let s = steps.first else { continue }
            #expect(s.rung == 0)
            #expect(s.phrases.count == PhrasePolicy.phrasesPerStep)
            #expect(s.phrases.allSatisfy { $0.count == 2 })
            let patterns = s.phrases.flatMap { $0 }
            #expect(patterns.allSatisfy { $0.pickupTicks == 0 && $0.meter.id == s.meterID })
            let units = Set(patterns.compactMap { Fixtures.curriculum.unit(containing: $0.id)?.id })
            #expect(units.isSubset(of: ["U1", "U3", "U9"]))
            let meter = Fixtures.library.meters[s.meterID]!
            #expect(s.tempo.bpm == (Tempo.standard(for: meter).bpm * 0.85).rounded())
        }
    }

    @Test func dailyCapAndNoMasteryRecords() {
        var p = progress(passingCSOf: ["U1"])
        for _ in 0..<PhrasePolicy.maxPhrasesPerDay {
            let newly = p.record(attempt(rung: 0, passed: true, day: 1), curriculum: Fixtures.curriculum, library: Fixtures.library,
                                 calendar: calendar)
            #expect(newly.isEmpty)
        }
        #expect(p.items.isEmpty) // no Leitner review item
        #expect(phraseSteps(p, day: 1).isEmpty)
        // "Read phrases" goes on as practice: same rung, never counted
        var rng = SeededRandomNumberGenerator(seed: 1)
        let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: calendar)
        let practice = planner.phrasePlan(p, date: Fixtures.day(1), using: &rng).steps.compactMap { if case .readPhrase(let s) = $0 { s } else { nil } }
        #expect(practice.count == 1)
        #expect(practice.first?.mode == .practice)
        #expect(practice.first?.rung == PhraseLadder.rung(after: p.attempts))
        #expect(phraseSteps(p, day: 2).first?.rung == PhraseLadder.rung(after: p.attempts))
    }
}
