import Testing
@testable import AudiateCore

@Suite("Pulse trainer")
struct PulseTrainerTests {
    let duple = Fixtures.library.meters["usual_duple"]!

    func trainer(_ mode: PulseTrainer.Mode = .blocks, subdivision: PulseTrainer.Subdivision = .macrobeats) -> PulseTrainer {
        PulseTrainer(settings: .init(meter: duple, tempo: Tempo(bpm: 80), subdivision: subdivision, mode: mode))
    }

    @Test func clickThenSilenceThenClick() {
        let t = trainer()
        #expect(t.measures.map(\.role) == [.click, .click, .silent, .silent, .click, .click])
        #expect(t.awaiting == 0)
        #expect(t.cycles[0].beats == [3.0, 3.75, 4.5, 5.25])
        #expect(t.sounds(from: 3.0, to: 6.0).isEmpty)
        #expect(!t.sounds(from: 6.0, to: 6.01).isEmpty) // the click is back: you hear the drift
        #expect(t.decidedUntil == 9.0)
    }

    @Test func steadyTapsLengthenTheSilenceDriftShortensIt() {
        var t = trainer()
        let r = t.report(taps: t.cycles[0].beats.map { $0 + 0.01 })
        #expect(r?.grade.passed == true)
        #expect(t.level == 1)
        #expect(t.cycles[1].measures == 4)
        #expect(t.measures.last?.role == .click)
        // rushing by a fifth of a beat → back down
        let beats = t.cycles[1].beats
        let rushed = beats.enumerated().map { beats[0] + Double($0.offset) * 0.75 * 0.97 }
        let r2 = t.report(taps: rushed)
        #expect((r2?.driftBeats ?? 0) < -0.15)
        #expect((r2?.tappedBPM ?? 0) > 80)                // rushed: a faster tempo
        #expect(t.level == 0)
        #expect(t.cycles[2].measures == 2)
    }

    @Test func randomDropoutsAreShortAndUnpredictable() {
        var t = trainer(.randomDropouts)
        for _ in 0..<20 {
            #expect(t.cycles.last!.measures <= PulseTrainer.Policy.runs[t.level])
            t.report(taps: t.cycles.last!.beats)
        }
        let lengths = Set(t.cycles.map(\.measures))
        #expect(lengths.count > 1)
        // clicked runs vary between silences too
        var runs: [Int] = []
        var count = 0
        for m in t.measures {
            if m.role == .click { count += 1 } else if count > 0 { runs.append(count); count = 0 }
        }
        #expect(Set(runs.dropFirst()).count > 1)
    }

    @Test func subdivisionsSetTheGrid() {
        #expect(trainer(subdivision: .macrobeats).cycles[0].beats.count == 4)
        #expect(trainer(subdivision: .microbeats).cycles[0].beats.count == 8)
        #expect(trainer(subdivision: .divisions).cycles[0].beats.count == 16)
    }
}
