import Testing
@testable import AudiateCore

@Suite("FlowSequencer")
struct FlowSequencerTests {
    let library = Fixtures.library

    func item(_ id: String, level: SkillLevel = .aural) -> PlannedItem {
        PlannedItem(patternID: id, unitID: Fixtures.curriculum.unit(containing: id)!.id, level: level, purpose: .new)
    }

    func echo(_ ids: [String], mode: PracticeMode, level: SkillLevel = .aural) -> SessionStep {
        let meter = Fixtures.pattern(ids[0]).meter
        return .echo(EchoBlockSpec(items: ids.map { item($0, level: level) }, meterID: meter.id,
                                   tempo: mode == .teaching ? TempoPolicy.teaching(for: meter) : .standard(for: meter),
                                   clickStage: mode == .teaching ? .a : .b, mode: mode, showNotation: false))
    }

    /// Reports outcomes in order until the stream ends; returns the attempts' (pattern, try).
    func run(_ steps: [SessionStep], outcomes: (FlowSequencer.FlowAttempt) -> Bool, more: [[SessionStep]] = []) -> FlowSequencer {
        var flow = FlowSequencer(steps: steps, library: library)
        var batches = more
        var guardCount = 0
        while let index = flow.awaiting, guardCount < 100 {
            guardCount += 1
            flow.report(passed: outcomes(flow.attempts[index]), forAttempt: index) {
                batches.isEmpty ? [] : batches.removeFirst()
            }
        }
        return flow
    }

    func expectContinuousPulse(_ flow: FlowSequencer) {
        for (a, b) in zip(flow.measures, flow.measures.dropFirst()) {
            #expect(abs(a.end - b.start) < 1e-9, "gap/overlap between \(a.role) and \(b.role)")
        }
        // every measure starts with a strong click: the metronome never stops
        for m in flow.measures {
            #expect(flow.sounds(from: m.start - 1e-9, to: m.start + 1e-9).contains { $0.sound == .click(accented: true) }, "\(m.role) at \(m.start)")
        }
    }

    @Test func attemptLayoutAndVerdictLeadIn() {
        let flow = FlowSequencer(steps: [echo(["D-MM-01"], mode: .evaluation)], library: library)
        #expect(flow.measures.map(\.role) == [.countIn, .prompt, .hold, .response, .leadIn])
        #expect(flow.awaiting == 0)
        let a = flow.attempts[0]
        #expect(a.response?.start == 4.5)                       // 80 BPM: 1.5 s per measure
        #expect(a.end == 6.0)
        #expect(flow.decidedUntil == 6.0 + 0.75)                // half of the lead-in is final
        #expect(flow.attempt(endingAt: 6.0)?.index == 0)
    }

    @Test func evaluationBlockFlowsWithOneMeasureBetweenAttempts() {
        let flow = run([echo(["D-MM-01", "D-MM-02", "D-MM-03"], mode: .evaluation)], outcomes: { _ in false })
        #expect(flow.attempts.map(\.pattern.id) == ["D-MM-01", "D-MM-02", "D-MM-03"]) // no retries in evaluation
        #expect(flow.measures.map(\.role) == [.countIn, .prompt, .hold, .response,
                                              .leadIn, .prompt, .hold, .response,
                                              .leadIn, .prompt, .hold, .response, .leadIn])
        #expect(flow.endTime == flow.measures.last?.end)
        expectContinuousPulse(flow)
    }

    @Test func teachingRepeatsUntilCorrectAtMostFourTimes() {
        let succeedsOnThird = run([echo(["D-MM-01"], mode: .teaching), echo(["D-MM-02"], mode: .teaching)],
                                  outcomes: { $0.pattern.id == "D-MM-01" ? $0.position.attempt == 3 : true })
        #expect(succeedsOnThird.attempts.map(\.position.attempt) == [1, 2, 3, 1])
        let neverSucceeds = run([echo(["D-MM-01"], mode: .teaching)], outcomes: { _ in false })
        #expect(neverSucceeds.attempts.count == MasteryPolicy.maxTeachingAttempts)
        expectContinuousPulse(succeedsOnThird)
    }

    @Test func newTempoGetsItsOwnCountIn() {
        // teaching (68 BPM) then evaluation (80 BPM): verdict measure in 68, count-in in 80
        let flow = run([echo(["D-MM-01"], mode: .teaching), echo(["D-MM-01", "D-MM-02", "D-MM-03"], mode: .evaluation)],
                       outcomes: { _ in true })
        let roles = flow.measures.map(\.role)
        #expect(Array(roles.prefix(7)) == [.countIn, .prompt, .hold, .response, .leadIn, .countIn, .prompt])
        #expect(flow.measures[4].duration > flow.measures[5].duration)
        expectContinuousPulse(flow)
    }

    @Test func nextSessionIsAppendedWhenThePlanRunsOut() {
        let flow = run([echo(["D-MM-01"], mode: .evaluation)], outcomes: { _ in true },
                       more: [[echo(["D-MM-02", "D-MM-03"], mode: .evaluation)]])
        #expect(flow.attempts.map(\.pattern.id) == ["D-MM-01", "D-MM-02", "D-MM-03"])
        #expect(flow.endTime != nil)
        expectContinuousPulse(flow)
    }

    @Test func pickupSoundsInTheLeadInOnlyOnceDecided() {
        var flow = FlowSequencer(steps: [echo(["D-MM-01", "D-UB-01"], mode: .evaluation)], library: library)
        let leadIn = flow.measures.last!
        #expect(!flow.sounds(from: leadIn.start, to: leadIn.end).contains { $0.sound == .hiHat })
        flow.report(passed: true, forAttempt: 0)
        // D-UB-01 has a 12-tick pickup: the last eighth of the lead-in
        let pickup = flow.sounds(from: leadIn.start, to: leadIn.end).filter { $0.sound == .hiHat }
        #expect(pickup.map(\.time) == [leadIn.start + 1.125])
        #expect(flow.attempts[1].start == leadIn.start)
        #expect(pickup[0].time >= leadIn.start + leadIn.duration * FlowSequencer.undecidedFraction)
    }

    @Test func nameTheNotationListensTwiceThenThePulseStopsForTheChoice() {
        let options = ["D-MM-02", "D-MM-01", "D-MM-03", "D-MM-04"].map(Fixtures.pattern)
        let q = NameNotationSpec(item: item("D-MM-02", level: .verbal), tempo: Tempo(bpm: 80), options: options,
                                 correctIndex: 0, mode: .evaluation)
        let flow = FlowSequencer(steps: [.nameNotation(q), echo(["D-MM-01"], mode: .evaluation)], library: library)
        #expect(flow.measures.map(\.role) == [.countIn, .prompt, .prompt, .leadIn])
        #expect(flow.attempts[0].response == nil)
        #expect(flow.attempts[0].question == q)
        let after = flow.measures.last!
        #expect(flow.sounds(from: after.start, to: after.end).isEmpty) // silent: the learner chooses without a clock
    }

    @Test func emptyPlanEndsImmediately() {
        let flow = FlowSequencer(steps: [], library: library)
        #expect(flow.endTime == 0)
        #expect(flow.awaiting == nil)
    }

    @Test func resumesAtAGivenPosition() {
        let flow = FlowSequencer(steps: [echo(["D-MM-01", "D-MM-02"], mode: .evaluation)], library: library,
                                 from: .init(step: 0, item: 1, attempt: 1))
        #expect(flow.attempts.first?.pattern.id == "D-MM-02")
        #expect(flow.attempts.first?.start == 0)
    }
}
