import AudiateCore
import Foundation

/// Dev check of the session screen against the audio: launch with `-AudiateSoak /path/frames.csv`.
/// Progress lives in memory (the real store is untouched), the audio is muted, and "Read phrases" runs
/// with no taps — every phrase missed, so the long review. Every frame is logged (uptime, heard time,
/// pulse light, measure role) for `seconds`, then the macrobeat clicks played, and the app quits.
@MainActor
final class SoakProbe {
    static let path = UserDefaults.standard.string(forKey: "AudiateSoak")
    static let shared: SoakProbe? = path.map { SoakProbe(path: $0) }
    static let seconds = 40.0

    private let path: String
    private let started = ProcessInfo.processInfo.systemUptime
    private var rows: [String] = ["kind,uptime,heard,lit,role"]
    private var done = false

    private init(path: String) { self.path = path }

    /// The learner's progress for the run: U1 and U2 past CS, their patterns heard.
    static func progress(_ content: AppModel.Content) -> LearnerProgress {
        let day = Date()
        var passedAt: [LevelKey: Date] = [:]
        var attempts: [Attempt] = []
        for id in ["U1", "U2"] {
            guard let unit = content.curriculum.unit(id: id) else { continue }
            for level in SkillLevel.allCases where level <= .compositeSynthesis { passedAt[LevelKey(unitID: id, level: level)] = day }
            attempts += content.curriculum.patterns(of: unit, in: content.library).map {
                Attempt(date: day, unitID: id, level: .aural, patternID: $0.id, exercise: .echo, mode: .teaching, passed: true, accuracy: 1)
            }
        }
        return LearnerProgress(attempts: attempts, passedAt: passedAt)
    }

    func frame(heard: Double?, lit: Bool, role: String, flow: FlowSequencer) {
        guard !done else { return }
        let now = ProcessInfo.processInfo.systemUptime
        rows.append("frame,\(now),\(heard ?? -1),\(lit ? 1 : 0),\(role)")
        guard now - started > Self.seconds, let heard else { return }
        done = true
        for click in flow.audible(from: 0, to: heard) where click.sound.isMacrobeatClick {
            rows.append("click,,\(click.time),,")
        }
        try? rows.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        exit(0)
    }
}
