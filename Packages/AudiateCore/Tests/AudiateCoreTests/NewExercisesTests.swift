import Foundation
import Testing
@testable import AudiateCore

/// The pulse grader behind the pulse trainer (E10 is no longer a session step).
@Suite("Pulse grader")
struct PulseGraderTests {
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
        #expect(flow.measures.map(\.role) == [.countIn, .countIn, .prompt, .prompt, .prompt, .prompt, .leadIn])
        let countIn = flow.measures[0], seriesMeasure = flow.measures[2]
        let clicks = flow.sounds(from: countIn.start, to: seriesMeasure.start)
        #expect(clicks.allSatisfy { $0.sound.isMacrobeatClick })   // no microbeats: they would give 6/8 away
        #expect(clicks.count == 4)
        // stage C: no clicks while the series plays
        #expect(!flow.sounds(from: seriesMeasure.start, to: flow.attempts[0].end).contains { $0.sound != .hiHat })
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

}

@Suite("Two hands and the audiation drill")
struct TwoHandsAndDrillTests {
    @Test func bothHandsMustPass() throws {
        let p = Fixtures.pattern("D-MM-02") // 12 12 24
        let t = try Timeline.echoBlock(patterns: [p], tempo: Tempo(bpm: 80), clickStage: .b)
        let slot = try #require(t.responses.first)
        #expect(slot.macrobeatTimes.count == 2)
        let good = TwoHandGrade.grade(slot: slot, rhythmTaps: slot.expectedOnsets, pulseTaps: slot.macrobeatTimes, mode: .absolute)
        #expect(good.passed && good.accuracy == 1)
        let lostPulse = TwoHandGrade.grade(slot: slot, rhythmTaps: slot.expectedOnsets, pulseTaps: [slot.macrobeatTimes[0]], mode: .absolute)
        #expect(lostPulse.rhythm.passed && !lostPulse.pulse.passed && !lostPulse.passed)
        #expect(lostPulse.pulse.errors == [.missedBeat])
    }

    @Test func drillClosesTheFirstSessionOfTheDay() {
        let planner = SessionPlanner(curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)
        var progress = LearnerProgress()
        var rng = SeededRandomNumberGenerator(seed: 4)
        // nothing heard yet → no drill on the very first day's first plan
        let first = planner.plan(progress, date: Fixtures.day(0), using: &rng)
        func drills(_ p: SessionPlan) -> [EchoBlockSpec] {
            p.steps.compactMap { if case .echo(let e) = $0, e.isAudiationDrill { e } else { nil } }
        }
        #expect(drills(first).isEmpty)
        for step in first.steps {
            for a in StepAttempts.perfect(step, at: Fixtures.day(0)) {
                progress.record(a, curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)
            }
        }
        let next = planner.plan(progress, date: Fixtures.day(1), using: &rng)
        let drill = try? #require(drills(next).first)
        #expect(drill?.clickStage == .c && drill?.mode == .practice && drill?.gapMeasures == MasteryPolicy.drillGapMeasures)
        if case .echo(let last) = next.steps.last { #expect(last.isAudiationDrill) } else { Issue.record("drill not last") }
        // and only once a day
        for a in StepAttempts.perfect(next.steps.last!, at: Fixtures.day(1)) {
            progress.record(a, curriculum: Fixtures.curriculum, library: Fixtures.library, calendar: Fixtures.calendar)
        }
        #expect(drills(planner.plan(progress, date: Fixtures.day(1), using: &rng)).isEmpty)
    }
}
