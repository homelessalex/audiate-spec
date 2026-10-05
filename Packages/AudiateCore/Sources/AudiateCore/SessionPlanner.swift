import Foundation

/// Builds today's session: review of due items, then new material at the frontier
/// (docs/02-curriculum.md §5). Warm-up and audiation drills arrive in M4.
public struct SessionPlanner: Sendable {
    public let curriculum: Curriculum
    public let library: PatternLibrary
    public var sessionSeconds: Double

    /// Levels that have exercises so far.
    public static let implementedLevels: Set<SkillLevel> = [.aural, .verbal]
    /// Evaluation echoes of one pattern in one session; more adds little before the next day.
    public static let maxEvaluationsPerPattern = 4

    public init(curriculum: Curriculum, library: PatternLibrary, sessionSeconds: Double = MasteryPolicy.sessionSeconds) {
        self.curriculum = curriculum
        self.library = library
        self.sessionSeconds = sessionSeconds
    }

    /// Lowest unpassed, unlocked level of the earliest unit that has one.
    public func frontier(_ progress: LearnerProgress) -> LevelKey? {
        for unit in curriculum.units {
            for level in SkillLevel.allCases where Self.implementedLevels.contains(level) {
                let key = LevelKey(unitID: unit.id, level: level)
                if progress.passed.contains(key) { continue }
                if Gate.isUnlocked(key, curriculum: curriculum, passed: progress.passed) { return key }
                break
            }
        }
        return nil
    }

    public func plan(_ progress: LearnerProgress, date: Date, using rng: inout some RandomNumberGenerator) -> SessionPlan {
        let frontier = frontier(progress)
        var steps = review(progress, date: date, excluding: frontier)
        if let frontier {
            steps += newMaterial(frontier, progress: progress, budget: sessionSeconds - seconds(steps), using: &rng)
        }
        return SessionPlan(steps: steps, frontier: frontier, estimatedSeconds: seconds(steps))
    }

    // MARK: - Review

    private func review(_ progress: LearnerProgress, date: Date, excluding frontier: LevelKey?) -> [SessionStep] {
        let items: [PlannedItem] = progress.dueItems(on: date).compactMap { state in
            guard Self.implementedLevels.contains(state.key.level), library.pattern(id: state.key.subject) != nil,
                  let unit = curriculum.unit(containing: state.key.subject),
                  LevelKey(unitID: unit.id, level: state.key.level) != frontier else { return nil }
            let purpose: PlannedItem.Purpose = progress.passed.contains(LevelKey(unitID: unit.id, level: state.key.level)) ? .review : .bridge
            return PlannedItem(patternID: state.key.subject, unitID: unit.id, level: state.key.level, purpose: purpose)
        }
        var steps: [SessionStep] = []
        let budget = sessionSeconds * MasteryPolicy.reviewShare
        for block in blocksByMeter(items, maxSize: MasteryPolicy.evaluationBlockSize.upperBound) {
            let step = echo(block, mode: .evaluation)
            if !steps.isEmpty, seconds(steps + [step]) > budget { break }
            steps.append(step)
        }
        return steps
    }

    // MARK: - New material

    private func newMaterial(_ key: LevelKey, progress: LearnerProgress, budget: Double,
                             using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        guard let unit = curriculum.unit(id: key.unitID) else { return [] }
        let patterns = curriculum.patterns(of: unit, in: library)
        let introduced = patterns.filter { progress.teachingCount(patternID: $0.id, level: key.level) >= MasteryPolicy.teachingEchoes }
        let fresh = patterns.filter { !introduced.contains($0) }.prefix(MasteryPolicy.maxNewPatternsPerSessionPerUnit)
        func item(_ p: Pattern) -> PlannedItem { PlannedItem(patternID: p.id, unitID: unit.id, level: key.level, purpose: .new) }

        var steps: [SessionStep] = fresh.map { p in
            echo(Array(repeating: item(p), count: MasteryPolicy.teachingEchoes), mode: .teaching)
        }

        let pool = introduced + fresh
        var remaining = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, Self.maxEvaluationsPerPattern) })
        while seconds(steps) < budget {
            let available = pool.filter { remaining[$0.id, default: 0] > 0 }.shuffled(using: &rng)
            guard !available.isEmpty else { break }
            var round: [Pattern] = []
            for p in available.sorted(by: { remaining[$0.id]! > remaining[$1.id]! }) {
                round.append(p)
                remaining[p.id]! -= 1
            }
            while round.count < MasteryPolicy.evaluationBlockSize.lowerBound,
                  let p = available.first(where: { remaining[$0.id]! > 0 }) {
                round.append(p)
                remaining[p.id]! -= 1
            }
            let blocks = blocksByMeter(round.shuffled(using: &rng).map(item), maxSize: MasteryPolicy.evaluationBlockSize.upperBound)
            steps += blocks.map { echo($0, mode: .evaluation) }
            if key.level == .verbal {
                steps += Set(round.map(\.id)).sorted().compactMap { library.pattern(id: $0) }.compactMap {
                    nameSyllables(item($0), pattern: $0, using: &rng)
                }
            }
        }
        return steps
    }

    // MARK: - Building blocks

    /// Same-meter blocks, at least `MasteryPolicy.minBlockSize` echoes (short ones repeat their items).
    private func blocksByMeter(_ items: [PlannedItem], maxSize: Int) -> [[PlannedItem]] {
        var order: [String] = []
        var byMeter: [String: [PlannedItem]] = [:]
        for item in items {
            guard let meter = library.pattern(id: item.patternID)?.meter.id else { continue }
            if byMeter[meter] == nil { order.append(meter) }
            byMeter[meter, default: []].append(item)
        }
        return order.flatMap { meter -> [[PlannedItem]] in
            let all = byMeter[meter]!
            return stride(from: 0, to: all.count, by: maxSize).map { start in
                var block = Array(all[start..<min(start + maxSize, all.count)])
                var i = 0
                while block.count < MasteryPolicy.minBlockSize { block.append(block[i]); i += 1 }
                return block
            }
        }
    }

    private func echo(_ items: [PlannedItem], mode: PracticeMode) -> SessionStep {
        let meter = library.pattern(id: items[0].patternID)!.meter
        let level = items[0].level
        return .echo(EchoBlockSpec(
            items: items, meterID: meter.id, tempo: .standard(for: meter),
            clickStage: mode == .teaching ? .a : .b, mode: mode,
            showSyllables: mode == .teaching && level >= .verbal
        ))
    }

    private func nameSyllables(_ item: PlannedItem, pattern: Pattern, using rng: inout some RandomNumberGenerator) -> SessionStep? {
        let deriver = SyllableDeriver()
        guard let line = try? deriver.line(for: pattern) else { return nil }
        let wrong = DistractorGenerator.distractors(for: pattern, library: library, using: &rng).compactMap { try? deriver.line(for: $0) }
        guard !wrong.isEmpty else { return nil }
        let options = ([line] + wrong).shuffled(using: &rng)
        return .nameSyllables(NameSyllablesSpec(item: item, tempo: .standard(for: pattern.meter), options: options,
                                                correctIndex: options.firstIndex(of: line)!, mode: .evaluation))
    }

    // MARK: - Time estimate

    func seconds(_ steps: [SessionStep]) -> Double {
        steps.map(seconds).reduce(0, +)
    }

    func seconds(_ step: SessionStep) -> Double {
        switch step {
        case .echo(let spec):
            guard let meter = library.meters[spec.meterID] else { return 0 }
            let measure = spec.tempo.seconds(forTicks: meter.measureTicks, in: meter)
            return Double(1 + 2 * spec.items.count) * measure + MasteryPolicy.stepOverheadSeconds
        case .nameSyllables:
            return MasteryPolicy.nameSyllablesSeconds
        }
    }
}
