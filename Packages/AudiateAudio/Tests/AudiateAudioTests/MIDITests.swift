import Testing
@testable import AudiateAudio

@Suite("MIDI input")
struct MIDITests {
    /// MIDI 1.0 channel voice UMP word: type 2, group 0.
    static func voice(_ status: UInt32, _ data1: UInt32, _ data2: UInt32) -> UInt32 {
        0x2000_0000 | status << 16 | data1 << 8 | data2
    }

    @Test(arguments: [
        // note-on, any channel
        ([voice(0x90, 60, 100)], [60]),
        ([voice(0x99, 36, 1)], [36]),
        // note-on with velocity 0 is a note-off; real note-off, CC and pitch bend are ignored
        ([voice(0x90, 60, 0), voice(0x80, 60, 64), voice(0xB0, 64, 127), voice(0xE0, 0, 64)], []),
        // a 2-word SysEx7 packet in between does not shift the parse
        ([0x3016_F07E, 0x9000_0000, voice(0x90, 62, 90), voice(0x90, 64, 90)], [62, 64]),
        // a 4-word message whose payload looks like a note-on is skipped as a whole
        ([0x5000_0000, voice(0x90, 1, 1), voice(0x90, 2, 2), voice(0x90, 3, 3), voice(0x90, 72, 80)], [72]),
        // a truncated trailing message does not crash
        ([voice(0x90, 48, 70), 0x4090_0000], [48]),
    ] as [([UInt32], [UInt8])])
    func parsesNoteOns(words: [UInt32], notes: [UInt8]) {
        #expect(UMPParser.noteOns(in: words).map(\.note) == notes)
    }

    @Test func oneHandEveryNoteIsRhythm() {
        let split = MIDISplit.standard
        for note: UInt8 in [0, 36, 59, 60, 127] {
            #expect(split.role(for: note, twoHands: false) == .rhythm)
        }
    }

    @Test func twoHandsSplitsAtLowestRhythmNote() {
        let split = MIDISplit(lowestRhythmNote: 48)
        #expect(split.role(for: 47, twoHands: true) == .pulse)
        #expect(split.role(for: 48, twoHands: true) == .rhythm)
        #expect(split.role(for: 90, twoHands: true) == .rhythm)
    }

    @Test func noteNames() {
        #expect(MIDINote.name(60) == "C4")
        #expect(MIDINote.name(61) == "C♯4")
        #expect(MIDINote.name(21) == "A0")
        #expect(MIDINote.name(0) == "C-1")
    }

    @Test func offsetsPerSource() {
        let offsets = InputOffsets(computer: 0.03, midi: 0.01)
        #expect(offsets[.computer] == 0.03)
        #expect(offsets[.midi] == 0.01)
    }
}
