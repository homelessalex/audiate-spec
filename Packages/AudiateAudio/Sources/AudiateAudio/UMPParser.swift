/// Picks MIDI 1.0 note-ons out of Universal MIDI Packet words (what CoreMIDI delivers for `._1_0`).
enum UMPParser {
    /// (note, velocity) of every note-on with velocity > 0; note-on with velocity 0 is a note-off.
    static func noteOns(in words: some Collection<UInt32>) -> [(note: UInt8, velocity: UInt8)] {
        var result: [(note: UInt8, velocity: UInt8)] = []
        var index = words.startIndex
        while index != words.endIndex {
            let word = words[index]
            let type = word >> 28
            // MIDI 1.0 channel voice message: 0x2g 9n kk vv
            if type == 0x2, (word >> 20) & 0xF == 0x9 {
                let note = UInt8((word >> 8) & 0x7F)
                let velocity = UInt8(word & 0x7F)
                if velocity > 0 { result.append((note, velocity)) }
            }
            let size = messageWords(type: type)
            index = words.index(index, offsetBy: size, limitedBy: words.endIndex) ?? words.endIndex
        }
        return result
    }

    /// UMP message size by message type (M2-104-UM §2.1.4).
    static func messageWords(type: UInt32) -> Int {
        switch type {
        case 0x0, 0x1, 0x2, 0x6, 0x7: 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: 2
        case 0xB, 0xC: 3
        default: 4
        }
    }
}
