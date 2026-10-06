/// One physical key, with the label shown to the learner.
public struct KeyBinding: Codable, Hashable, Sendable {
    public let keyCode: UInt16
    public let label: String

    public init(keyCode: UInt16, label: String) {
        self.keyCode = keyCode
        self.label = label
    }
}

/// Which keys tap the rhythm and which tap the pulse; set by the learner in Settings.
public struct KeyMap: Codable, Hashable, Sendable {
    public var rhythm: [KeyBinding]
    public var pulse: [KeyBinding]

    public init(rhythm: [KeyBinding], pulse: [KeyBinding]) {
        self.rhythm = rhythm
        self.pulse = pulse
    }

    public static let standard = KeyMap(rhythm: [KeyBinding(keyCode: 49, label: "Space"), KeyBinding(keyCode: 38, label: "J")],
                                        pulse: [KeyBinding(keyCode: 3, label: "F")])

    public func role(for keyCode: UInt16) -> TapKey? {
        if rhythm.contains(where: { $0.keyCode == keyCode }) { return .rhythm }
        if pulse.contains(where: { $0.keyCode == keyCode }) { return .pulse }
        return nil
    }

    /// Keys the app needs for itself: 1–9 and 0 (answers), Return (continue), Esc (pause),
    /// arrows and Delete (writing with cells), Tab.
    public static let reserved: Set<UInt16> = [18, 19, 20, 21, 22, 23, 25, 26, 28, 29, 36, 76, 53, 123, 124, 125, 126, 51, 117, 48]

    public static func isAllowed(_ keyCode: UInt16) -> Bool { !reserved.contains(keyCode) }

    public var rhythmLabels: String { rhythm.map(\.label).joined(separator: " / ") }
    public var pulseLabels: String { pulse.map(\.label).joined(separator: " / ") }
}
