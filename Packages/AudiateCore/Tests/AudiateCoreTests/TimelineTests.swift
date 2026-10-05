import Testing
@testable import AudiateCore

@Suite("Timeline")
struct TimelineTests {
    func block(_ ids: [String], stage: ClickStage = .b, voice: PromptVoice = .neutral, bpm: Double? = nil) throws -> Timeline {
        let patterns = ids.map(Fixtures.pattern)
        let tempo = bpm.map(Tempo.init(bpm:)) ?? Tempo.standard(for: patterns[0].meter)
        return try Timeline.echoBlock(patterns: patterns, tempo: tempo, clickStage: stage, voice: voice)
    }

    @Test func tempoConversion() throws {
        let duple = Fixtures.pattern("D-MM-01").meter
        let triple = Fixtures.pattern("T-MM-01").meter
        let fiveEight = Fixtures.pattern("UP-MM-01").meter
        // 80 BPM duple: quarter = 0.75 s; 60 BPM triple: dotted quarter = 1 s; eighth = 200: 0.3 s
        #expect(abs(Tempo(bpm: 80).seconds(forTicks: 24, in: duple) - 0.75) < 1e-12)
        #expect(abs(Tempo(bpm: 60).seconds(forTicks: 36, in: triple) - 1.0) < 1e-12)
        #expect(abs(Tempo(bpm: 200).seconds(forTicks: 12, in: fiveEight) - 0.3) < 1e-12)
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
        let prompt = t.sounds.filter { $0.sound == .neutral }.map(\.time)
        #expect(prompt == [1.5, 1.6875, 1.875, 2.0625, 2.25])
    }

    @Test func countInSpeaksMacrobeatsInUsualAndMicrobeatsInUnusualMeters() throws {
        let usual = try block(["D-MM-01"])
        #expect(usual.sounds.filter { $0.time < usual.measureDuration && $0.sound.isVoice }.map(\.sound)
                == [.syllable("Du"), .syllable("Du")])
        let unusual = try block(["UP-MM-01"])
        #expect(unusual.sounds.filter { $0.time < unusual.measureDuration && $0.sound.isVoice }.map(\.sound)
                == ["Du", "be", "Du", "ba", "bi"].map(Sound.syllable))
    }

    @Test func pickupShortensCountInAndPrecedesResponse() throws {
        let t = try block(["D-UB-01"], bpm: 80) // pickup 12 | 24 24, measure 1.5 s, tick = 1/32 s
        let countInVoice = t.sounds.filter { $0.time < 1.5 && $0.sound.isVoice && $0.sound != .neutral }
        #expect(countInVoice.map(\.time) == [0, 0.75]) // nothing at or after the pickup (1.125 s)
        #expect(t.sounds.contains { $0.sound == .neutral && $0.time == 1.125 })
        let slot = try #require(t.responses.first)
        #expect(slot.start == 3.0 - 0.375)
        #expect(slot.expectedOnsets == [2.625, 3.0, 3.75])
    }

    @Test func clickStages() throws {
        func clicks(_ stage: ClickStage) throws -> (countIn: [Sound], after: [Sound]) {
            let t = try block(["D-MM-01"], stage: stage)
            let c = t.sounds.filter { !$0.sound.isVoice }
            return (c.filter { $0.time < t.measureDuration }.map(\.sound), c.filter { $0.time >= t.measureDuration }.map(\.sound))
        }
        let a = try clicks(.a)
        #expect(a.countIn == [.click(accented: true), .click(accented: false), .click(accented: true), .click(accented: false)])
        #expect(a.after.count == 8)
        let b = try clicks(.b)
        #expect(b.countIn == [.click(accented: true), .click(accented: true)])
        #expect(b.after.count == 4)
        #expect(try clicks(.c).after.isEmpty)
        #expect(try clicks(.d).after.isEmpty)
    }

    @Test func syllableVoiceAndSilentRestsAndTies() throws {
        let t = try block(["D-TI-01"], voice: .syllables) // 12 12~ 12 12 → Du de [Du] de
        let promptVoice = t.sounds.filter { $0.time >= t.measureDuration && $0.sound.isVoice }.map(\.sound)
        #expect(promptVoice == [.syllable("Du"), .syllable("de"), .syllable("de")])
        let rest = try block(["D-RS-01"], voice: .neutral) // 24 r24
        #expect(rest.responses[0].expectedOnsets.count == 1)
    }

    @Test func blockOfSeveralPatterns() throws {
        let t = try block(["D-MM-01", "D-MM-02", "D-MM-03"], bpm: 80)
        #expect(t.responses.map(\.start) == [3.0, 6.0, 9.0])
        #expect(t.responses.map(\.patternID) == ["D-MM-01", "D-MM-02", "D-MM-03"])
        #expect(t.duration == 10.5)
        #expect(t.sounds == t.sounds.sorted { $0.time < $1.time })
    }

    @Test func mixedMetersAreRejected() {
        #expect(throws: TimelineError.self) { try block(["D-MM-01", "T-MM-01"]) }
        #expect(throws: TimelineError.self) {
            try Timeline.echoBlock(patterns: [], tempo: Tempo(bpm: 80), clickStage: .a, voice: .neutral)
        }
    }
}
