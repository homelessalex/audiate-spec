import CoreAudio

/// The current default output device, read through Core Audio.
public struct OutputDevice: Hashable, Sendable {
    public let uid: String
    public let name: String
    public let isBluetooth: Bool
    /// Hardware I/O buffer, seconds.
    public let ioBufferDuration: Double

    public static func current() -> OutputDevice? {
        guard let id: AudioDeviceID = property(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice) else {
            return nil
        }
        let transport: UInt32 = property(id, kAudioDevicePropertyTransportType) ?? 0
        let frames: UInt32 = property(id, kAudioDevicePropertyBufferFrameSize, scope: kAudioObjectPropertyScopeOutput) ?? 0
        let rate: Float64 = property(id, kAudioDevicePropertyNominalSampleRate) ?? 0
        return OutputDevice(
            uid: string(id, kAudioDevicePropertyDeviceUID) ?? "unknown",
            name: string(id, kAudioObjectPropertyName) ?? "Unknown output",
            isBluetooth: transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE,
            ioBufferDuration: rate > 0 ? Double(frames) / rate : 0
        )
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func property<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                    scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> T? {
        var addr = address(selector, scope: scope)
        var size = UInt32(MemoryLayout<T>.size)
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, value) == noErr else { return nil }
        return value.pointee
    }

    private static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
