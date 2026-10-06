import Foundation

/// Builds today's session (docs/02-curriculum.md §5): review of due items, then new material at the
/// ear frontier. Notation appears from VA on (after the unit passed AO by ear); reading from SA.
/// Every tap step is played pattern by pattern, each attempt with its own count-in; teaching repeats a
/// pattern until it is correct. Warm-up and audiation drills arrive in M4.
public struct SessionPlanner: Sendable {
    public let curriculum: Curriculum
    public let library: PatternLibrary
    public var sessionSeconds: Double

    /// Levels that have exercises so far.
    public static let implementedLevels: Set<SkillLevel> = [.aural, .verbal, .symbolic]
    /// The ear levels that move the frontier from unit to unit.
    static let earLevels: [SkillLevel] = [.aural, .verbal]
    /// Evaluations of one pattern per exercise in one session; more adds little before the next day.
    public static let maxEvaluationsPerPattern = 4

    public init(curriculum: Curriculum, library: PatternLibrary, sessionSeconds: Double = MasteryPolicy.sessionSeconds) {
        self.curriculum = curriculum
        self.library = library
        self.sessionSeconds = sessionSeconds
    }

    /// Lowest unpassed, unlocked ear level of the earliest unit that has one.
    public func frontier(_ progress: LearnerProgress) -> LevelKey? {
        for unit in curriculum.units {
            for level in Self.earLevels {
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
        var taughtNow: Set<String> = []
        if let frontier {
            steps += newMaterial(frontier, progress: progress, budget: sessionSeconds - seconds(steps),
                                 taughtNow: &taughtNow, using: &rng)
        }
        steps += otherReading(progress, frontier: frontier, budget: sessionSeconds - seconds(steps), using: &rng)
        return SessionPlan(steps: steps, frontier: frontier, estimatedSeconds: seconds(steps))
    }

    // MARK: - Review

    private func review(_ progress: LearnerProgress, date: Date, excluding frontier: LevelKey?) -> [SessionStep] {
        let items: [PlannedItem] = progress.dueItems(on: date).compactMap { state in
            let level = state.key.level
            guard Self.implementedLevels.contains(level), library.pattern(id: state.key.subject) != nil,
                  let unit = curriculum.unit(containing: state.key.subject) else { return nil }
            let key = LevelKey(unitID: unit.id, level: level)
            let passed = progress.passed.contains(key)
            // unpassed reading is practiced by the reading track; the frontier by new material
            guard key != frontier, passed || level != .symbolic else { return nil }
            return PlannedItem(patternID: state.key.subject, unitID: unit.id, level: level, purpose: passed ? .review : .bridge)
        }
        var steps: [SessionStep] = []
        let budget = sessionSeconds * MasteryPolicy.reviewShare
        for block in blocksByMeterAndLevel(items) {
            let step = block[0].level == .symbolic ? read(block, mode: .evaluation) : echo(block, mode: .evaluation)
            if !steps.isEmpty, seconds(steps + [step]) > budget { break }
            steps.append(step)
        }
        return steps
    }

    // MARK: - New material

    private func newMaterial(_ key: LevelKey, progress: LearnerProgress, budget: Double, taughtNow: inout Set<String>,
                             using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        guard let unit = curriculum.unit(id: key.unitID) else { return [] }
        let patterns = curriculum.patterns(of: unit, in: library)
        let introduced = patterns.filter { progress.isIntroduced(patternID: $0.id, level: key.level) }
        let fresh = patterns.filter { !introduced.contains($0) }.prefix(MasteryPolicy.maxNewPatternsPerSessionPerUnit)
        let readsUnit = isReading(unit, progress)
        func item(_ p: Pattern, _ level: SkillLevel) -> PlannedItem {
            PlannedItem(patternID: p.id, unitID: unit.id, level: level, purpose: .new)
        }

        var steps: [SessionStep] = []
        for p in fresh {
            steps.append(echo([item(p, key.level)], mode: .teaching))
            if key.level == .aural {
                taughtNow.insert(p.id)
                if readsUnit {
                    steps.append(read([item(p, .symbolic)], mode: .teaching))
                }
            }
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
            let shuffled = round.shuffled(using: &rng)
            steps += blocksByMeterAndLevel(shuffled.map { item($0, key.level) }).map { echo($0, mode: .evaluation) }
            if key.level == .verbal {
                steps += Set(round.map(\.id)).sorted().compactMap { library.pattern(id: $0) }.compactMap {
                    nameNotation(item($0, .verbal), pattern: $0, using: &rng)
                }
            }
            if readsUnit {
                let readable = shuffled.filter { progress.hasHeard(patternID: $0.id) || taughtNow.contains($0.id) }
                steps += blocksByMeterAndLevel(readable.map { item($0, .symbolic) }).map { read($0, mode: .evaluation) }
            }
        }
        return steps
    }

    /// Reading for earlier units whose ear levels are done but whose reading isn't passed yet.
    private func otherReading(_ progress: LearnerProgress, frontier: LevelKey?, budget: Double,
                              using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        let items = curriculum.units.filter { $0.id != frontier?.unitID && isReading($0, progress) }.flatMap { unit in
            curriculum.patterns(of: unit, in: library)
                .filter { progress.hasHeard(patternID: $0.id) }
                .map { PlannedItem(patternID: $0.id, unitID: unit.id, level: .symbolic, purpose: .new) }
        }
        var steps: [SessionStep] = []
        for block in blocksByMeterAndLevel(items.shuffled(using: &rng)) {
            let step = read(block, mode: .evaluation)
            if seconds(steps + [step]) > budget { break }
            steps.append(step)
        }
        return steps
    }

    private func isReading(_ unit: CurriculumUnit, _ progress: LearnerProgress) -> Bool {
        let key = LevelKey(unitID: unit.id, level: .symbolic)
        return !progress.passed.contains(key) && Gate.isUnlocked(key, curriculum: curriculum, passed: progress.passed)
    }

    // MARK: - Building blocks

    /// Same-meter, same-level blocks of 3…6 (short ones repeat their items).
    private func blocksByMeterAndLevel(_ items: [PlannedItem]) -> [[PlannedItem]] {
        let maxSize = MasteryPolicy.evaluationBlockSize.upperBound
        var order: [String] = []
        var groups: [String: [PlannedItem]] = [:]
        for item in items {
            guard let meter = library.pattern(id: item.patternID)?.meter.id else { continue }
            let key = "\(meter)|\(item.level.rawValue)"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(item)
        }
        return order.flatMap { key -> [[PlannedItem]] in
            let all = groups[key]!
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
            items: items, meterID: meter.id, tempo: mode == .teaching ? TempoPolicy.teaching(for: meter) : .standard(for: meter),
            clickStage: mode == .teaching ? .a : .b, mode: mode,
            showNotation: level >= .verbal
        ))
    }

    private func read(_ items: [PlannedItem], mode: PracticeMode) -> SessionStep {
        let meter = library.pattern(id: items[0].patternID)!.meter
        return .read(ReadBlockSpec(items: items, meterID: meter.id,
                                   tempo: mode == .teaching ? TempoPolicy.teaching(for: meter) : .standard(for: meter),
                                   clickStage: mode == .teaching ? .a : .b, mode: mode))
    }

    private func nameNotation(_ item: PlannedItem, pattern: Pattern, using rng: inout some RandomNumberGenerator) -> SessionStep? {
        let wrong = DistractorGenerator.distractors(for: pattern, library: library, using: &rng)
        guard !wrong.isEmpty else { return nil }
        let options = ([pattern] + wrong).shuffled(using: &rng)
        return .nameNotation(NameNotationSpec(item: item, tempo: .standard(for: pattern.meter), options: options,
                                              correctIndex: options.firstIndex(of: pattern)!, mode: .evaluation))
    }

    // MARK: - Time estimate

    func seconds(_ steps: [SessionStep]) -> Double {
        steps.map(seconds).reduce(0, +)
    }

    func seconds(_ step: SessionStep) -> Double {
        /// Each attempt: count-in + its measures + the verdict; teaching is assumed to take two attempts.
        func attempts(_ meterID: String, _ tempo: Tempo, items: Int, measuresPerAttempt: Int, mode: PracticeMode) -> Double {
            guard let meter = library.meters[meterID] else { return 0 }
            let attempt = Double(1 + measuresPerAttempt) * tempo.seconds(forTicks: meter.measureTicks, in: meter) + MasteryPolicy.verdictSeconds
            return Double(items) * attempt * (mode == .teaching ? 2 : 1) + MasteryPolicy.stepOverheadSeconds
        }
        switch step {
        case .echo(let s): return attempts(s.meterID, s.tempo, items: s.items.count, measuresPerAttempt: 2 + EchoPolicy.gapMeasures, mode: s.mode)
        case .read(let s): return attempts(s.meterID, s.tempo, items: s.items.count, measuresPerAttempt: 2, mode: s.mode)
        case .nameNotation: return MasteryPolicy.nameNotationSeconds
        }
    }
}
