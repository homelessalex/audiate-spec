import Testing
@testable import AudiateCore

@Suite("Timeline")
struct TimelineTests {
    /// Without the hold measure unless asked, so the times below stay simple.
    func block(_ ids: [String], stage: ClickStage = .b, bpm: Double? = nil, gap: Int = 0) throws -> Timeline {
        let patterns = ids.map(Fixtures.pattern)
        let tempo = bpm.map(Tempo.init(bpm:)) ?? Tempo.standard(for: patterns[0].meter)
        return try Timeline.echoBlock(patterns: patterns, tempo: tempo, clickStage: stage, gapMeasures: gap)
    }

    @Test func holdMeasureBetweenPromptAndResponse() throws {
        let t = try block(["D-MM-01", "D-MM-02"], bpm: 80, gap: 1)
        #expect(t.measureRoles == [.countIn, .prompt(0), .hold(0), .response(0), .prompt(1), .hold(1), .response(1)])
        #expect(t.responses.map(\.start) == [4.5, 9.0])
        #expect(t.prompts.map(\.start) == [1.5, 6.0])
        #expect(t.duration == 10.5)
        #expect(t.role(at: 3.2) == .hold(0))
        #expect(t.role(at: -0.1) == nil)
        #expect(t.role(at: 10.6) == nil)
        // the pulse goes on through the hold measure (stage B: macrobeats)
        #expect(t.sounds.filter { $0.sound == .click(accented: true) && $0.time >= 3.0 && $0.time < 4.5 }.count == 2)
        #expect(EchoPolicy.gapMeasures == 1)
    }

    @Test func readBlockHasNoPromptSoundAndALookAheadMeasure() throws {
        let p = Fixtures.pattern("D-MM-02")
        let t = try Timeline.readBlock(patterns: [p, p], tempo: Tempo(bpm: 80), clickStage: .b)
        #expect(!t.sounds.contains { $0.sound == .hiHat })
        #expect(t.measureRoles == [.countIn, .prompt(0), .response(0), .prompt(1), .response(1)])
        #expect(t.responses.map(\.start) == [3.0, 6.0])
        #expect(t.prompts[0].cues.map(\.text) == ["Du", "de", "Du"])
    }

    func hiHats(_ t: Timeline) -> [ScheduledSound] { t.sounds.filter { $0.sound == .hiHat } }
    func clicks(_ t: Timeline) -> [ScheduledSound] { t.sounds.filter { $0.sound != .hiHat } }

    @Test func tempoConversion() throws {
        let duple = Fixtures.pattern("D-MM-01").meter
        let triple = Fixtures.pattern("T-MM-01").meter
        let fiveEight = Fixtures.pattern("UP-MM-01").meter
        // 80 BPM duple: quarter = 0.75 s; 60 BPM triple: dotted quarter = 1 s; eighth = 200: 0.3 s
        #expect(abs(Tempo(bpm: 80).seconds(forTicks: 24, in: duple) - 0.75) < 1e-12)
        #expect(abs(Tempo(bpm: 60).seconds(forTicks: 36, in: triple) - 1.0) < 1e-12)
        #expect(abs(Tempo(bpm: 200).seconds(forTicks: 12, in: fiveEight) - 0.3) < 1e-12)
    }

    @Test(arguments: ["D-MM-01", "T-MM-01", "UP-MM-01"])
    func teachingTempoIsSlowerButWithinTheRange(id: String) {
        let meter = Fixtures.pattern(id).meter
        let teaching = TempoPolicy.teaching(for: meter).bpm
        #expect(teaching < Tempo.standard(for: meter).bpm)
        #expect(TempoPolicy.range(for: meter).contains(teaching))
    }

    @Test func echoLayoutCountInPromptResponse() throws {
        let t = try block(["D-DV-03"], bpm: 80) // 6 6 6 6 24
        #expect(t.measureDuration == 1.5)
        #expect(t.duration == 4.5)
        let slot = try #require(t.responses.first)
        #expect(slot.start == 3.0)
        #expect(slot.end == 4.5)
        #expect(slot.expectedOnsets == [3.0, 3.1875, 3.375, 3.5625, 3.75])
        #expect(slot.macrobeatTimes == [3.0, 3.75])
        #expect(hiHats(t).map(\.time) == [1.5, 1.6875, 1.875, 2.0625, 2.25])
    }

    @Test func promptNotesSustainForTheirDuration() throws {
        let el = try block(["D-EL-02"], bpm: 80) // 36 12
        #expect(hiHats(el).map(\.duration) == [1.125, 0.375])
        let rest = try block(["D-RS-01"], bpm: 80) // 24 r24: the rest is silence
        #expect(hiHats(rest).map(\.duration) == [0.75])
        let tie = try block(["D-TI-02"], bpm: 80) // 24~ 6 6 12: tied note sounds 30 ticks, no new onset
        #expect(hiHats(tie).map(\.duration) == [0.9375, 0.1875, 0.375])
        #expect(clicks(el).allSatisfy { $0.duration == nil })
    }

    @Test func syllableCuesFollowThePrompt() throws {
        let t = try block(["D-TI-01"], bpm: 80) // 12 12~ 12 12 → Du de [Du] de
        let prompt = try #require(t.prompts.first)
        #expect(prompt.cues.map(\.text) == ["Du", "de", "[Du]", "de"])
        #expect(prompt.cues.map(\.time) == [1.5, 1.875, 2.25, 2.625])
        #expect(prompt.start == 1.5 && prompt.end == 3.0)
        let up = try block(["D-UB-02"], bpm: 80) // pickup 6 6 | 24 24
        #expect(up.prompts[0].cues.map(\.text) == ["de", "ta", "Du", "Du"])
        #expect(up.prompts[0].start == 1.5 - 0.375)
    }

    @Test func countInClicksMacroAndMicroBeats() throws {
        let duple = try block(["D-MM-01"], stage: .c)
        #expect(clicks(duple).map(\.sound) == [true, false, true, false].map(Sound.click))
        let unusual = try block(["UP-MM-01"], stage: .c) // 2+3
        #expect(clicks(unusual).map(\.sound) == [true, false, true, false, false].map(Sound.click))
    }

    @Test func pickupShortensCountIn() throws {
        let t = try block(["D-UB-01"], stage: .c, bpm: 80) // pickup 12 | 24 24, pickup at 1.125 s
        #expect(clicks(t).map(\.time) == [0, 0.375, 0.75])
        #expect(hiHats(t).first?.time == 1.125)
        let slot = try #require(t.responses.first)
        #expect(slot.start == 3.0 - 0.375)
        #expect(slot.expectedOnsets == [2.625, 3.0, 3.75])
        // stage B keeps its macrobeat clicks through the pickup
        #expect(clicks(try block(["D-UB-01"], stage: .b, bpm: 80)).filter { $0.time < 1.5 }.map(\.time) == [0, 0.375, 0.75])
    }

    @Test func clickStages() throws {
        func after(_ stage: ClickStage) throws -> [Sound] {
            let t = try block(["D-MM-01"], stage: stage)
            return clicks(t).filter { $0.time >= t.measureDuration }.map(\.sound)
        }
        #expect(try after(.a).count == 8)
        #expect(try after(.b) == Array(repeating: .click(accented: true), count: 4))
        #expect(try after(.c).isEmpty)
        #expect(try after(.d).isEmpty)
    }

    @Test func restsAreNotExpected() throws {
        #expect(try block(["D-RS-01"]).responses[0].expectedOnsets.count == 1)
    }

    @Test func blockOfSeveralPatterns() throws {
        let t = try block(["D-MM-01", "D-MM-02", "D-MM-03"], bpm: 80)
        #expect(t.responses.map(\.start) == [3.0, 6.0, 9.0])
        #expect(t.prompts.map(\.start) == [1.5, 4.5, 7.5])
        #expect(t.responses.map(\.patternID) == ["D-MM-01", "D-MM-02", "D-MM-03"])
        #expect(t.duration == 10.5)
        #expect(t.sounds == t.sounds.sorted { $0.time < $1.time })
    }

    @Test func mixedMetersAreRejected() {
        #expect(throws: TimelineError.self) { try block(["D-MM-01", "T-MM-01"]) }
        #expect(throws: TimelineError.self) {
            try Timeline.echoBlock(patterns: [], tempo: Tempo(bpm: 80), clickStage: .a)
        }
    }
}
