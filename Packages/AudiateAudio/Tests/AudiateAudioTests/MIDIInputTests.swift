import AVFoundation
import CoreMIDI
import Testing
@testable import AudiateAudio

/// End to end through CoreMIDI: a virtual source appears, gets connected, and its note-on arrives on
/// the main actor with the packet's host time.
@Suite("MIDI input (CoreMIDI)")
@MainActor
struct MIDIInputTests {
    @Test func virtualSourceDeliversTimestampedNoteOn() async throws {
        let input = MIDIInput.shared
        try #require(input.error == nil)
        var client = MIDIClientRef()
        try #require(MIDIClientCreateWithBlock("AudiateTest" as CFString, &client, nil) == noErr)
        var source = MIDIEndpointRef()
        try #require(MIDISourceCreateWithProtocol(client, "Audiate Test Keys" as CFString, ._1_0, &source) == noErr)
        defer { MIDIEndpointDispose(source); MIDIClientDispose(client) }

        for _ in 0..<100 where !input.sourceNames.contains("Audiate Test Keys") {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(input.sourceNames.contains("Audiate Test Keys"))

        var received: [MIDINote] = []
        let token = input.addListener { received.append($0) }
        defer { input.removeListener(token) }

        let hostTime = mach_absolute_time()
        var list = MIDIEventList()
        let packet = MIDIEventListInit(&list, ._1_0)
        var words: [UInt32] = [0x2093_3C64, 0x2093_3C00] // note-on C4 vel 100, then its note-off (vel 0)
        MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, hostTime, words.count, &words)
        #expect(MIDIReceivedEventList(source, &list) == noErr)

        for _ in 0..<100 where received.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(received.map(\.note) == [60])
        #expect(received.first?.velocity == 100)
        #expect(abs((received.first?.timestamp ?? 0) - AVAudioTime.seconds(forHostTime: hostTime)) < 1e-6)
    }
}
