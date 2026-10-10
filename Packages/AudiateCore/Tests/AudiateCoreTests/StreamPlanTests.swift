import Foundation
import Testing
@testable import AudiateCore

/// The audio renders on its own from `StreamPlan` snapshots; the UI may decide late. The pulse must stay
/// on its grid whatever the timing of the decisions (docs/05-architecture.md §3).
@Suite("Stream plan")
struct StreamPlanTests {
    let click = ScheduledSound(time: 0, sound: .click(tick: 0, micro: 0))

    @Test func decidedSoundsThenTheContinuation() {
        let decided = [0.0, 0.5, 1.0, 1.5].map { ScheduledSound(time: $0, sound: .click(tick: 0, micro: 0)) }
        let plan = StreamPlan(sounds: decided + [ScheduledSound(time: 2.5, sound: .hiHat)], decidedUntil: 1.75, endTime: nil,
                              continuation: ClickContinuation(gridStart: 1.0, measure: 1.0, clicks: [click]))
        // 2.5 lies past decidedUntil: not decided yet, the continuation plays instead (clicks at 2, 3)
        #expect(plan.sounds(from: 0, to: 4)?.map(\.time) == [0, 0.5, 1, 1.5, 2, 3])
        #expect(plan.sounds(from: 1.2, to: 2.1)?.map(\.time) == [1.5, 2])
    }

    @Test func endsAtTheEndTime() {
        let plan = StreamPlan(sounds: [click], decidedUntil: 1, endTime: 1, continuation: nil)
        #expect(plan.sounds(from: 0, to: 0.5)?.count == 1)
        #expect(plan.sounds(from: 1, to: 2) == nil)
    }

    // MARK: The flow with an audio thread that never waits

    /// Renders `flow` in chunks like the audio thread, reporting each attempt (all missed) when the UI
    /// gets to it: `uiDelay` after the attempt ends. Returns the times of everything played.
    func play(_ steps: [SessionStep], uiDelay: Double, until: Double) -> (played: [ScheduledSound], flow: FlowSequencer) {
        var flow = FlowSequencer(steps: steps, library: Fixtures.library)
        var plan = flow.plan
        var played: [ScheduledSound] = []
        let chunk = 1024.0 / 48_000, ahead = 8 * chunk
        var rendered = 0.0
        var clock = 0.0
        while clock < until {
            // the audio stays `ahead` of the clock, whatever the UI does
            while rendered < clock + ahead {
                played += plan.sounds(from: rendered, to: rendered + chunk) ?? []
                rendered += chunk
            }
            if let i = flow.awaiting, clock >= flow.attempts[i].end + uiDelay {
                flow.report(passed: false, forAttempt: i, notBefore: rendered + chunk)
                plan = flow.plan
            }
            clock += 0.01
        }
        return (played, flow)
    }

    func echoSteps() -> [SessionStep] {
        let p = Fixtures.pattern("D-MM-02")
        let items = (0..<4).map { _ in PlannedItem(patternID: p.id, unitID: "U1", level: .verbal, purpose: .review) }
        return [.echo(EchoBlockSpec(items: items, meterID: p.meter.id, tempo: Tempo(bpm: 80), clickStage: .b, mode: .evaluation,
                                    showNotation: true))]
    }

    @Test(arguments: [0.0, 0.3, 0.9, 2.5])
    func clicksStayOnTheGridWhenTheUIIsLate(uiDelay: Double) {
        let (played, flow) = play(echoSteps(), uiDelay: uiDelay, until: 30)
        let macrobeat = 60.0 / 80
        let start = flow.measures[0].start
        let clicks = played.filter { $0.sound != .hiHat }.map(\.time)
        // every click on the eighth-note grid of the one tempo, none twice
        for t in clicks {
            let k = (t - start) / (macrobeat / 2)
            #expect(abs(k - k.rounded()) < 1e-6, "click at \(t) off the grid")
        }
        #expect(Set(clicks.map { Int(($0 * 1000).rounded()) }).count == clicks.count)
        // no macrobeat without its click: the pulse never drops out
        let downbeats = Set(clicks.map { Int((($0 - start) / macrobeat).rounded()) })
        let last = downbeats.max() ?? 0
        #expect(downbeats == Set(0...last))
        // and every prompt note laid out was played: nothing new was placed where the audio had been
        let prompts = flow.plan.sounds.filter { $0.sound == .hiHat && $0.time < 28 }.map(\.time)
        let heard = Set(played.filter { $0.sound == .hiHat }.map { Int(($0.time * 1e6).rounded()) })
        #expect(prompts.allSatisfy { heard.contains(Int(($0 * 1e6).rounded())) })
        #expect(flow.attempts.count >= 3)
    }

    @Test func aLateOutcomeHoldsTheLeadInInsteadOfShiftingThePulse() {
        let (_, early) = play(echoSteps(), uiDelay: 0, until: 12)
        let (_, late) = play(echoSteps(), uiDelay: 2.5, until: 12)
        // the second attempt starts later, by whole measures
        let d = early.attempts[0].measureDuration
        let shift = (late.attempts[1].start - early.attempts[1].start) / d
        #expect(shift >= 1)
        #expect(abs(shift - shift.rounded()) < 1e-9)
    }

    @Test func phraseReviewAndLateOutcome() {
        let phrase = ["D-MM-02", "D-DV-01"].map(Fixtures.pattern)
        let spec = PhraseSpec(phrases: [phrase, phrase], rung: 0, meterID: phrase[0].meter.id, tempo: Tempo(bpm: 56))
        let (played, flow) = play([.readPhrase(spec)], uiDelay: 1.5, until: 40)
        let macrobeat = 60.0 / 56
        let clicks = played.filter { $0.sound != .hiHat }.map(\.time)
        let start = flow.measures[0].start
        let beats = Set(clicks.map { Int((($0 - start) / macrobeat).rounded()) })
        #expect(beats == Set(0...(beats.max() ?? 0)))
        #expect(flow.attempts.count >= 2)
    }

    /// The pulse light reads `audible` every frame; it must be exactly what the audio plays.
    @Test func audibleIsWhatTheAudioPlays() {
        var flow = FlowSequencer(steps: echoSteps(), library: Fixtures.library)
        flow.report(passed: true, forAttempt: 0)
        for from in stride(from: 0.0, to: 20, by: 0.37) {
            let plan = flow.plan.sounds(from: from, to: from + 0.37) ?? []
            #expect(Set(flow.audible(from: from, to: from + 0.37)) == Set(plan))
        }
        // past the decided part: the continuation's macrobeats
        let past = flow.decidedUntil + 3
        #expect(flow.audible(from: past, to: past + 2).contains { $0.sound.isMacrobeatClick })
    }
}
