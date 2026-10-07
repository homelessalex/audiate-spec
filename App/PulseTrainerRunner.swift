import AudiateAudio
import AudiateCore
import Foundation
import Observation

/// Runs the pulse trainer: endless click / silence cycles until stopped. Each silence is graded when it
/// ends; its result shows while the click plays, and decides the next silence.
@MainActor
@Observable
final class PulseTrainerRunner {
    enum State {
        case setup
        case running
        case finished
    }

    var settings: PulseTrainer.Settings
    private(set) var state: State = .setup
    private(set) var trainer: PulseTrainer?
    let recorder = TapRecorder()

    private let content: AppModel.Content
    private unowned let model: AppModel
    private var ticker: Task<Void, Never>?

    init(content: AppModel.Content, model: AppModel) {
        self.content = content
        self.model = model
        let meter = content.library.meters["usual_duple"]!
        settings = .init(meter: meter, tempo: .standard(for: meter), subdivision: .macrobeats, mode: .blocks)
    }

    var meters: [Meter] { content.library.meters.values.filter { $0.id != "usual_combined" }.sorted { $0.id < $1.id } }
    var heardTime: Double? { recorder.heardTime() }
    var results: [PulseTrainer.Result] { trainer?.results ?? [] }

    func start() {
        let trainer = PulseTrainer(settings: settings, seed: UInt64.random(in: 0...UInt64.max))
        self.trainer = trainer
        do {
            let clock = try content.player.stream(
                provider: { [weak self] from, to in self?.provide(from: from, to: to) },
                onFinish: {}
            )
            // either hand, any key keeps the beat here
            recorder.start(clock: clock, player: content.player, setup: model.tapSetup(twoHands: false))
            state = .running
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    self?.gradeIfDue()
                    try? await Task.sleep(for: .milliseconds(30))
                }
            }
        } catch {
            state = .setup
        }
    }

    func stop() {
        ticker?.cancel()
        content.player.stop()
        recorder.stop()
        state = trainer?.results.isEmpty == false ? .finished : .setup
    }

    func again() { state = .setup }

    private func provide(from: Double, to: Double) -> [ScheduledSound]? {
        if trainer?.awaiting != nil, to > (trainer?.decidedUntil ?? 0) { report() }
        return trainer?.sounds(from: from, to: to)
    }

    private func gradeIfDue() {
        guard let trainer, let index = trainer.awaiting, let heard = heardTime, heard >= trainer.cycles[index].end else { return }
        report()
    }

    private func report() {
        let taps = recorder.taps + recorder.pulseTaps
        trainer?.report(taps: taps)
    }
}
