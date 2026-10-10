import AppKit
import AudiateAudio
import AudiateCore
import Foundation
import Observation
import SwiftData

/// Loads bundled content, owns the audio engine, the store and the learner's progress.
@MainActor
@Observable
final class AppModel {
    struct Content {
        let library: PatternLibrary
        let curriculum: Curriculum
        let player: BlockPlayer
    }

    let content: Content?
    let loadError: String?
    let container: ModelContainer
    let calendar = Calendar.current
    let settings = AppSettings()
    private(set) var progress = LearnerProgress()
    var session: SessionRunner?
    /// The current calendar day. Views that depend on "today" read it, so they refresh when the day changes.
    private(set) var today = Date.distantPast
    private var dayObservers: [NSObjectProtocol] = []
    var pulseTrainer: PulseTrainerRunner?

    /// Date injection: launch with `-AudiateDayOffset N` to pretend it's N days later.
    let dayOffset = UserDefaults.standard.integer(forKey: "AudiateDayOffset")

    init() {
        do {
            // the soak check (SoakProbe) keeps its progress in memory: the real store stays untouched
            container = try ModelContainer(for: CalibrationProfile.self, AttemptRecord.self, ItemStateRecord.self, LevelPassRecord.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: SoakProbe.path != nil))
        } catch {
            fatalError("SwiftData container: \(error)")
        }
        do {
            content = try Self.load(from: .main)
            loadError = nil
        } catch {
            content = nil
            loadError = "\(error)"
        }
        progress = store.load()
        refreshDay()
        if SoakProbe.path != nil, let content {
            content.player.isMuted = true
            progress = SoakProbe.progress(content)
            startSession(phrasesOnly: true)
        }
        // a new day can arrive at midnight, after the Mac wakes, or while the app was in the background
        let center = NotificationCenter.default, workspace = NSWorkspace.shared.notificationCenter
        for (nc, name) in [(center, Notification.Name.NSCalendarDayChanged),
                           (center, NSApplication.didBecomeActiveNotification),
                           (workspace, NSWorkspace.didWakeNotification)] {
            dayObservers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshDay() }
            })
        }

        if let path = UserDefaults.standard.string(forKey: "AudiateContactSheet"), let library = content?.library {
            ContactSheet.export(library: library, to: path)
            exit(0)
        }
        if let path = UserDefaults.standard.string(forKey: "AudiateAnswerSheet"), let library = content?.library {
            ContactSheet.exportAnswers(library: library, to: path)
            exit(0)
        }
        if let path = UserDefaults.standard.string(forKey: "AudiateFeedbackSheet"), let library = content?.library {
            ContactSheet.exportFeedback(library: library, to: path)
            exit(0)
        }
    }

    var library: PatternLibrary? { content?.library }
    var player: BlockPlayer? { content?.player }
    var outputDevice: OutputDevice? { OutputDevice.current() }
    private var store: ProgressStore { ProgressStore(context: container.mainContext) }

    func refreshDay() {
        let day = calendar.startOfDay(for: now())
        if day != today { today = day }
    }

    func now() -> Date {
        Date().addingTimeInterval(Double(dayOffset) * 86_400)
    }

    /// Input offsets in seconds for the current output, 0 if not calibrated.
    var inputOffsets: InputOffsets { container.mainContext.inputOffsets(for: outputDevice) }

    /// Tap input for exercises: the learner's keys, MIDI split, tap sound and calibrated offsets.
    func tapSetup(twoHands: Bool) -> TapSetup {
        TapSetup(keyMap: settings.keyMap, midiSplit: settings.midiSplit, twoHands: twoHands,
                 tapSound: settings.tapSound, offsets: inputOffsets)
    }

    /// Records and persists an attempt; returns levels that became passed.
    @discardableResult
    func record(_ attempt: Attempt) -> [LevelKey] {
        guard let content else { return [] }
        let before = progress
        let passed = progress.record(attempt, curriculum: content.curriculum, library: content.library, calendar: calendar)
        store.save(attempt, before: before, after: progress)
        return passed
    }

    func planSession() -> SessionPlan? {
        guard let content else { return nil }
        let planner = SessionPlanner(curriculum: content.curriculum, library: content.library,
                                     sessionSeconds: Double(settings.sessionMinutes) * 60, calendar: calendar)
        var rng = SystemRandomNumberGenerator()
        return planner.plan(progress, date: now(), using: &rng)
    }

    /// Unlimited practice of what has been taught; never counted toward mastery.
    func planFreePractice() -> SessionPlan? {
        guard let content else { return nil }
        let planner = SessionPlanner(curriculum: content.curriculum, library: content.library, calendar: calendar)
        var rng = SystemRandomNumberGenerator()
        return planner.freePractice(progress, using: &rng)
    }

    var planner: SessionPlanner? {
        content.map { SessionPlanner(curriculum: $0.curriculum, library: $0.library, calendar: calendar) }
    }

    /// Today's phrases (E13) only, step after step until the day's are done.
    func planPhrases() -> SessionPlan? {
        var rng = SystemRandomNumberGenerator()
        return planner?.phrasePlan(progress, date: now(), using: &rng)
    }

    /// Today's work, or free practice once it is done; or only the phrases.
    func startSession(freePractice: Bool = false, phrasesOnly: Bool = false) {
        guard let content, let plan = phrasesOnly ? planPhrases() : (freePractice ? planFreePractice() : planSession()),
              !plan.isEmpty else { return }
        session = SessionRunner(plan: plan, content: content, model: self, freePractice: freePractice, phrasesOnly: phrasesOnly)
    }

    /// Deletes every attempt, review item and passed level (calibration is kept).
    func resetProgress() {
        endSession()
        let context = container.mainContext
        try? context.delete(model: AttemptRecord.self)
        try? context.delete(model: ItemStateRecord.self)
        try? context.delete(model: LevelPassRecord.self)
        try? context.save()
        progress = LearnerProgress()
    }

    func openPulseTrainer() {
        guard let content else { return }
        pulseTrainer = PulseTrainerRunner(content: content, model: self)
    }

    func closePulseTrainer() { pulseTrainer = nil }

    func endSession() {
        session?.end()
        session = nil
    }

    private static func load(from bundle: Bundle) throws -> Content {
        guard let patterns = bundle.url(forResource: "patterns", withExtension: "json"),
              let cells = bundle.url(forResource: "cells", withExtension: "json"),
              let curriculum = bundle.url(forResource: "curriculum", withExtension: "json"),
              let samples = bundle.url(forResource: "Samples", withExtension: nil) else {
            throw AppError.missingResource
        }
        return Content(
            library: try PatternLibrary(patternsJSON: Data(contentsOf: patterns), cellsJSON: Data(contentsOf: cells)),
            curriculum: try Curriculum(json: Data(contentsOf: curriculum)),
            player: try BlockPlayer(bank: SampleBank.load(directory: samples))
        )
    }
}

enum AppError: Error {
    case missingResource
}
