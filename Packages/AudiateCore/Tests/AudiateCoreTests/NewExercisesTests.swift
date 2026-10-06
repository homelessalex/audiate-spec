import Foundation
import Testing
@testable import AudiateCore

@Suite("Hold the pulse (E10)")
struct HoldPulseTests {
    let beats = (0..<8).map { Double($0) * 0.75 } // 4 measures of 2/4 at 80 BPM

    @Test func steadyTapsPass() {
        let g = PulseGrader.grade(beats: beats, taps: beats.map { $0 + 0.01 })
        #expect(g.passed)
        #expect(abs(g.drift - 0.01 / 0.75) < 1e-9)
    }

    @Test func slowingDownIsDrift() {
        let slower = beats.enumerated().map { Double($0.offset) * 0.75 * 1.03 } // 3 % slower: ends 0.16 s late
        let g = PulseGrader.grade(beats: beats, taps: slower)
        #expect(g.problems == [.drifted])
        #expect(g.drift > 0.1)
    }

    @Test func unevenTapsAndLostCount() {
        let uneven = beats.enumerated().map { $0.element + ($0.offset.isMultiple(of: 2) ? 0.07 : -0.07) }
        #expect(PulseGrader.grade(beats: beats, taps: uneven).problems.contains(.uneven))
        #expect(PulseGrader.grade(beats: beats, taps: Array(beats.dropLast(2))).problems.contains(.lostCount))
        #expect(PulseGrader.grade(beats: beats, taps: []).problems == [.lostCount])
    }

    @Test func silenceGrowsWithPassesAndShrinksAfterAMiss() {
        #expect(PulsePolicy.silentMeasures(after: []) == 2)
        #expect(PulsePolicy.silentMeasures(after: [true]) == 4)
        #expect(PulsePolicy.silentMeasures(after: [true, true, true, true]) == 16)
        #expect(PulsePolicy.silentMeasures(after: [true, true, false]) == 4)
    }

    @Test func flowLayoutClickThenSilence() {
        let spec = HoldPulseSpec(unitID: "U1", meterID: "usual_duple", tempo: Tempo(bpm: 80), silentMeasures: 2)
        let flow = FlowSequencer(steps: [.holdPulse(spec)], library: Fixtures.library)
        #expect(flow.measures.map(\.role) == [.countIn, .withClick, .silent, .silent, .leadIn])
        let a = flow.attempts[0]
        #expect(a.response?.expectedOnsets == [3.0, 3.75, 4.5, 5.25])
        #expect(flow.sounds(from: 3.0, to: 6.0).isEmpty)            // silence
        #expect(!flow.sounds(from: 6.0, to: 6.01).isEmpty)          // the click returns: you hear your drift
    }
}

@Suite("Dictation (E6)")
struct DictationTests {
    let library = Fixtures.library

    @Test(arguments: Fixtures.rawPatterns)
    func cellsRoundTrip(raw: RawPattern) throws {
        let p = Fixtures.pattern(raw.id)
        guard let cells = Dictation.cells(for: p, in: library) else {
            // not writable with cells: a pickup, a tie or a note across a macrobeat
            #expect(p.pickupTicks > 0 || p.events.contains { $0.tieToNext }
                    || p.events.contains { e in p.meter.macrobeat(containing: e.startTick).index != p.meter.macrobeat(containing: e.endTick - 1).index })
            return
        }
        let rebuilt = try #require(Dictation.pattern(from: cells, meter: p.meter))
        #expect(rebuilt.shape == p.shape)
    }

    @Test func mostEarlyPatternsAreWritable() {
        let writable = ["D-MM-01", "D-MM-02", "D-MM-03", "D-MM-04", "T-MM-01", "T-MM-02", "D-DV-01"]
        #expect(writable.allSatisfy { Dictation.cells(for: Fixtures.pattern($0), in: library) != nil })
    }

    @Test func firstDifferenceAndPalette() throws {
        let p = Fixtures.pattern("D-MM-03") // 24 | 12 12
        let answer = try #require(Dictation.cells(for: p, in: library))
        #expect(Dictation.firstDifference(answer: answer, written: answer) == nil)
        #expect(Dictation.firstDifference(answer: answer, written: [answer[0], answer[0]]) == 1)
        #expect(Dictation.firstDifference(answer: answer, written: [nil, answer[1]]) == 0)
        let palette = Dictation.palette(for: p.meter, contents: [.macroMicro], answer: answer, library: library)
        #expect(answer.allSatisfy(palette.contains))
        #expect(palette.allSatisfy { $0.minContent == .macroMicro })
    }
}

@Suite("Meter identification (E3, E7) and stage C")
struct MeterIdentificationTests {
    let library = Fixtures.library

    @Test func clickStageByLevelAndMode() {
        #expect(ClickStage.forStep(level: .aural, mode: .teaching) == .a)
        #expect(ClickStage.forStep(level: .aural, mode: .evaluation) == .b)
        #expect(ClickStage.forStep(level: .verbal, mode: .evaluation) == .c)
        #expect(ClickStage.forStep(level: .symbolic, mode: .evaluation) == .c)
        #expect(ClickStage.forStep(level: .verbal, mode: .practice) == .b)
    }

    @Test func whichMeterCountInGivesOnlyTheMacrobeat() {
        let series = ["T-MM-01", "T-MM-02", "T-MM-03", "T-MM-04"].map(Fixtures.pattern)
        let spec = WhichMeterSpec(unitID: "U2", level: .partialSynthesis, series: series, options: ["usual_duple", "usual_triple"],
                                  correctIndex: 1, tempo: Tempo(bpm: TempoPolicy.meterIdentificationBPM))
        let flow = FlowSequencer(steps: [.whichMeter(spec)], library: library)
        #expect(flow.measures.map(\.role) == [.countIn, .prompt, .prompt, .prompt, .prompt, .leadIn])
        let countIn = flow.measures[0]
        let clicks = flow.sounds(from: countIn.start, to: countIn.end)
        #expect(clicks.allSatisfy { $0.sound == .click(accented: true) })   // no microbeats: they would give 6/8 away
        #expect(clicks.count == 2)
        // stage C: no clicks while the series plays
        #expect(!flow.sounds(from: countIn.end, to: flow.attempts[0].end).contains { $0.sound != .hiHat })
    }

    @Test func freshStartAndSilentKinds() {
        let series = ["D-MM-01", "D-MM-02", "D-MM-03", "D-MM-04"].map(Fixtures.pattern)
        let e7 = MeterFromNotationSpec(unitID: "U1", series: series, options: ["usual_duple", "usual_triple"], correctIndex: 0)
        var flow = FlowSequencer(steps: [.echo(EchoBlockSpec(items: [PlannedItem(patternID: "D-MM-01", unitID: "U1", level: .verbal, purpose: .new)],
                                                             meterID: "usual_duple", tempo: Tempo(bpm: 80), clickStage: .c,
                                                             mode: .evaluation, showNotation: true)),
                                         .meterFromNotation(e7)], library: library)
        flow.report(passed: true, forAttempt: 0)
        #expect(flow.endTime == flow.measures.last?.end)                   // the stream ends after the verdict measure
        #expect(flow.restartPosition == .init(step: 1, item: 0, attempt: 1))
        let silent = FlowSequencer(steps: flow.steps, library: library, from: flow.restartPosition!)
        #expect(silent.attempts[0].kind == .meterFromNotation)
        #expect(silent.endTime == 0 && silent.measures.isEmpty && silent.awaiting == 0)
    }

    @Test func unitLevelMasteryForPSAndCS() {
        let ps = LevelKey(unitID: "U1", level: .partialSynthesis)
        func attempts(_ n: Int, day: Int) -> [Attempt] {
            (0..<n).map { Attempt(date: Fixtures.day(day, hour: $0), unitID: "U1", level: .partialSynthesis, patternID: nil,
                                  exercise: .whichMeter, mode: .evaluation, passed: true, accuracy: 1) }
        }
        #expect(!MasteryEvaluator.isPassed(ps, patternIDs: [], attempts: attempts(10, day: 0), calendar: Fixtures.calendar))
        #expect(MasteryEvaluator.isPassed(ps, patternIDs: [], attempts: attempts(4, day: 0) + attempts(4, day: 1), calendar: Fixtures.calendar))
    }

    @Test func plannerWarmsUpOnceADay() {
        let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: library, calendar: Fixtures.calendar)
        var rng = SeededRandomNumberGenerator(seed: 1)
        let first = planner.plan(LearnerProgress(), date: Fixtures.day(0), using: &rng)
        guard case .holdPulse(let h) = first.steps.first else { Issue.record("no warm-up"); return }
        #expect(h.silentMeasures == 2)
        var progress = LearnerProgress()
        progress.record(Attempt(date: Fixtures.day(0), unitID: "U1", level: .aural, patternID: nil, exercise: .holdThePulse,
                                mode: .practice, passed: true, accuracy: 1),
                        curriculum: Fixtures.curriculum, library: library, calendar: Fixtures.calendar)
        let again = planner.plan(progress, date: Fixtures.day(0), using: &rng)
        #expect(!again.steps.contains { if case .holdPulse = $0 { true } else { false } })
        guard case .holdPulse(let next) = planner.plan(progress, date: Fixtures.day(1), using: &rng).steps.first else {
            Issue.record("no warm-up next day"); return
        }
        #expect(next.silentMeasures == 4)
    }
}
