import AudiateAudio
import Foundation
import Observation

/// The learner's settings, kept in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    /// Session length the planner aims for, minutes (5–30).
    var sessionMinutes: Int {
        didSet { defaults.set(sessionMinutes, forKey: "sessionMinutes") }
    }

    /// Left hand (F) keeps the macrobeats while the right hand plays the rhythm; both graded.
    var twoHandMode: Bool {
        didSet { defaults.set(twoHandMode, forKey: "twoHandMode") }
    }

    /// A short tick on every tap.
    var tapSound: Bool {
        didSet { defaults.set(tapSound, forKey: "tapSound") }
    }

    /// Which keys tap the rhythm and the pulse.
    var keyMap: KeyMap {
        didSet { defaults.set(try? JSONEncoder().encode(keyMap), forKey: "keyMap") }
    }

    var didShowIntroduction: Bool {
        didSet { defaults.set(didShowIntroduction, forKey: "didShowIntroduction") }
    }

    init() {
        let minutes = defaults.integer(forKey: "sessionMinutes")
        sessionMinutes = minutes == 0 ? 12 : minutes
        twoHandMode = defaults.bool(forKey: "twoHandMode")
        tapSound = defaults.object(forKey: "tapSound") as? Bool ?? true
        didShowIntroduction = defaults.bool(forKey: "didShowIntroduction")
        keyMap = defaults.data(forKey: "keyMap").flatMap { try? JSONDecoder().decode(KeyMap.self, from: $0) } ?? .standard
    }
}
