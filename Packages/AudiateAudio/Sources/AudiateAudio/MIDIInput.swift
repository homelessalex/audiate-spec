import AVFoundation
import CoreMIDI
import Observation

/// Listens to every connected MIDI source and reports note-ons with their CoreMIDI host timestamps.
/// One per app: CoreMIDI clients are meant to live as long as the process.
@MainActor
@Observable
public final class MIDIInput {
    public static let shared = MIDIInput()

    /// Names of the connected sources, for Settings.
    public private(set) var sourceNames: [String] = []
    public private(set) var error: String?

    public var isConnected: Bool { !sourceNames.isEmpty }

    @ObservationIgnored private var client = MIDIClientRef()
    @ObservationIgnored private var port = MIDIPortRef()
    @ObservationIgnored private var connected: Set<MIDIEndpointRef> = []
    @ObservationIgnored private var listeners: [UInt64: @MainActor (MIDINote) -> Void] = [:]
    @ObservationIgnored private var nextToken: UInt64 = 0

    private init() {
        let changed = Self.makeNotifyBlock { Task { @MainActor in MIDIInput.shared.connectSources() } }
        var status = MIDIClientCreateWithBlock("Audiate" as CFString, &client, changed)
        if status == noErr {
            let received = Self.makeReceiveBlock { notes in Task { @MainActor in MIDIInput.shared.deliver(notes) } }
            status = MIDIInputPortCreateWithProtocol(client, "Audiate input" as CFString, ._1_0, &port, received)
        }
        if status != noErr {
            error = "MIDI is unavailable (CoreMIDI error \(status))."
            return
        }
        connectSources()
    }

    /// Calls `handler` on the main actor for every note-on until `removeListener` is called with the token.
    public func addListener(_ handler: @escaping @MainActor (MIDINote) -> Void) -> UInt64 {
        nextToken += 1
        listeners[nextToken] = handler
        return nextToken
    }

    public func removeListener(_ token: UInt64) {
        listeners[token] = nil
    }

    private func deliver(_ notes: [MIDINote]) {
        for note in notes {
            for handler in listeners.values { handler(note) }
        }
    }

    /// Connects to sources that appeared and forgets the ones that went away.
    private func connectSources() {
        guard port != 0 else { return }
        var current: Set<MIDIEndpointRef> = []
        var names: [String] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(i)
            guard source != 0, !Self.isOffline(source) else { continue }
            current.insert(source)
            names.append(Self.name(of: source))
            if !connected.contains(source) { MIDIPortConnectSource(port, source, nil) }
        }
        for gone in connected.subtracting(current) { MIDIPortDisconnectSource(port, gone) }
        connected = current
        sourceNames = names
    }

    private static func isOffline(_ endpoint: MIDIEndpointRef) -> Bool {
        var offline: Int32 = 0
        MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline)
        return offline != 0
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String {
        var name: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name) == noErr, let name else { return "MIDI device" }
        return name.takeRetainedValue() as String
    }

    // CoreMIDI calls these blocks on its own threads, so they are built outside the main actor.

    private nonisolated static func makeNotifyBlock(_ changed: @escaping @Sendable () -> Void) -> MIDINotifyBlock {
        { @Sendable message in
            if message.pointee.messageID == .msgSetupChanged { changed() }
        }
    }

    private nonisolated static func makeReceiveBlock(_ deliver: @escaping @Sendable ([MIDINote]) -> Void) -> MIDIReceiveBlock {
        { @Sendable eventList, _ in
            var notes: [MIDINote] = []
            for packet in eventList.unsafeSequence() {
                let count = Int(packet.pointee.wordCount)
                let hostTime = packet.pointee.timeStamp == 0 ? mach_absolute_time() : packet.pointee.timeStamp
                let seconds = AVAudioTime.seconds(forHostTime: hostTime)
                withUnsafeBytes(of: packet.pointee.words) { raw in
                    let words = raw.bindMemory(to: UInt32.self).prefix(count)
                    for on in UMPParser.noteOns(in: words) {
                        notes.append(MIDINote(note: on.note, velocity: on.velocity, timestamp: seconds))
                    }
                }
            }
            if !notes.isEmpty { deliver(notes) }
        }
    }
}
