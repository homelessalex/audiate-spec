import Foundation

/// Builds today's session (docs/02-curriculum.md §5): review of due items, then new material at the
/// ear frontier. Notation appears from VA on (after the unit passed AO by ear); reading from SA.
/// Every tap step is played pattern by pattern, each attempt with its own count-in; teaching repeats a
/// pattern until it is correct. Warm-up and audiation drills arrive in M4.
public struct SessionPlanner: Sendable {
    public let curriculum: Curriculum
    public let library: PatternLibrary
    public var sessionSeconds: Double
    /// Defines "today" for the daily limits.
    public var calendar: Calendar

    /// Levels whose items are reviewed (familiar-pattern levels with exercises).
    public static let implementedLevels: Set<SkillLevel> = [.aural, .verbal, .symbolic]
    /// Unit-level attempts (E3, E7, CS series) per unit per exercise per day.
    public static let maxUnitAttemptsPerDay = 4
    /// Patterns in an E3/E7/CS series.
    public static let seriesLength = 4
    /// The ear levels that move the frontier from unit to unit.
    static let earLevels: [SkillLevel] = [.aural, .verbal]

    public init(curriculum: Curriculum, library: PatternLibrary, sessionSeconds: Double = MasteryPolicy.sessionSeconds,
                calendar: Calendar = .current) {
        self.curriculum = curriculum
        self.library = library
        self.sessionSeconds = sessionSeconds
        self.calendar = calendar
    }

    /// For every unit with one: its lowest unpassed, unlocked ear level (the units of a group run in parallel).
    public func frontiers(_ progress: LearnerProgress) -> [LevelKey] {
        curriculum.units.compactMap { unit in
            for level in Self.earLevels {
                let key = LevelKey(unitID: unit.id, level: level)
                if progress.passed.contains(key) { continue }
                return Gate.isUnlocked(key, curriculum: curriculum, passed: progress.passed) ? key : nil
            }
            return nil
        }
    }

    /// Today's next session. Daily limits make it empty once the day's work is done, which ends the flow.
    public func plan(_ progress: LearnerProgress, date: Date, using rng: inout some RandomNumberGenerator) -> SessionPlan {
        let frontiers = frontiers(progress)
        var steps = warmUp(progress, date: date)
        steps += review(progress, date: date, excluding: Set(frontiers))
        var taughtNow: Set<String> = []
        for (k, frontier) in frontiers.enumerated() {
            let share = (sessionSeconds - seconds(steps)) / Double(frontiers.count - k)
            steps += newMaterial(frontier, progress: progress, date: date, budget: share, taughtNow: &taughtNow, using: &rng)
        }
        steps += otherReading(progress, frontiers: Set(frontiers.map(\.unitID)), date: date,
                              budget: sessionSeconds - seconds(steps), using: &rng)
        steps += unitLevels(progress, date: date, using: &rng)
        if steps.contains(where: { if case .holdPulse = $0 { false } else { true } }) {
            steps += audiationDrill(progress, date: date, using: &rng)
        }
        return SessionPlan(steps: steps, frontiers: frontiers, estimatedSeconds: seconds(steps))
    }

    /// Once a day, closing the first session: familiar patterns, then two silent measures with no click
    /// before the echo — the pattern has to be held in audiation (E11). Practice, never counted.
    private func audiationDrill(_ progress: LearnerProgress, date: Date, using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        let doneToday = progress.attempts.contains { $0.mode == .practice && $0.exercise == .audiateTheGap
            && calendar.isDate($0.date, inSameDayAs: date) }
        let heard = curriculum.units.flatMap { unit in
            curriculum.patterns(of: unit, in: library).filter { progress.hasHeard(patternID: $0.id) }.map { (unit, $0) }
        }
        guard !doneToday, let pick = heard.randomElement(using: &rng) else { return [] }
        let sameMeter = heard.filter { $0.1.meter == pick.1.meter }.shuffled(using: &rng).prefix(MasteryPolicy.drillPatterns)
        let items = sameMeter.map { PlannedItem(patternID: $0.1.id, unitID: $0.0.id, level: .aural, purpose: .review) }
        return [.echo(EchoBlockSpec(items: Array(items), meterID: pick.1.meter.id, tempo: .standard(for: pick.1.meter),
                                    clickStage: .c, mode: .practice, showNotation: false, gapMeasures: MasteryPolicy.drillGapMeasures))]
    }

    // MARK: - Pulse

    /// E10 once a day before anything else.
    private func warmUp(_ progress: LearnerProgress, date: Date) -> [SessionStep] {
        let doneToday = progress.attempts.contains { $0.exercise == .holdThePulse && calendar.isDate($0.date, inSameDayAs: date) }
        guard !doneToday, let step = holdPulse(progress) else { return [] }
        return [step]
    }

    /// E10 in the meter of the earliest open unit, at the length its history has earned.
    private func holdPulse(_ progress: LearnerProgress) -> SessionStep? {
        let unit = frontiers(progress).first.flatMap { curriculum.unit(id: $0.unitID) } ?? curriculum.units.first
        guard let unit, let meterID = unit.meters.first, let meter = library.meters[meterID] else { return nil }
        return .holdPulse(HoldPulseSpec(unitID: unit.id, meterID: meterID, tempo: .standard(for: meter),
                                        silentMeasures: PulsePolicy.silentMeasures(after: progress.pulseHistory)))
    }

    // MARK: - PS, SA writing, CS

    /// Per unit with the level open: E3 "which meter?" (PS), E6 dictation (SA), E7 and series reading (CS).
    private func unitLevels(_ progress: LearnerProgress, date: Date, using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        var steps: [SessionStep] = []
        let knownMeters = curriculum.units.filter { progress.passed.contains(LevelKey(unitID: $0.id, level: .verbal)) }.flatMap(\.meters)
        let meterOptions = knownMeters.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let contents: Set<ContentKind> = Set(curriculum.units
            .filter { progress.passed.contains(LevelKey(unitID: $0.id, level: .verbal)) }
            .flatMap { curriculum.patterns(of: $0, in: library).map(\.content) }).union([.macroMicro])

        for unit in curriculum.units {
            func open(_ level: SkillLevel) -> Bool {
                let key = LevelKey(unitID: unit.id, level: level)
                return !progress.passed.contains(key) && Gate.isUnlocked(key, curriculum: curriculum, passed: progress.passed)
            }
            func left(_ level: SkillLevel, _ exercise: ExerciseKind, cap: Int = Self.maxUnitAttemptsPerDay) -> Bool {
                progress.unitEvaluationsOnDay(of: date, unitID: unit.id, level: level, exercise: exercise, calendar: calendar) < cap
            }
            let patterns = curriculum.patterns(of: unit, in: library)

            if open(.symbolic) {
                for p in patterns.shuffled(using: &rng) where progress.hasHeard(patternID: p.id) {
                    guard progress.evaluationsOnDay(of: date, patternID: p.id, level: .symbolic, exercise: .write, calendar: calendar)
                            < MasteryPolicy.maxEvaluationsPerPatternPerDay,
                          let answer = Dictation.cells(for: p, in: library) else { continue }
                    steps.append(.dictation(DictationSpec(
                        item: PlannedItem(patternID: p.id, unitID: unit.id, level: .symbolic, purpose: .new),
                        tempo: .standard(for: p.meter), answer: answer,
                        palette: Dictation.palette(for: p.meter, contents: contents, answer: answer, library: library),
                        mode: .evaluation)))
                }
            }
            if open(.partialSynthesis), left(.partialSynthesis, .whichMeter), meterOptions.count >= 2,
               let series = series(unit, patterns, using: &rng) {
                let meter = series[0].meter
                let tempo = meter.isUnusual ? Tempo.standard(for: meter) : Tempo(bpm: TempoPolicy.meterIdentificationBPM)
                let options = meterOptions.shuffled(using: &rng)
                steps.append(.whichMeter(WhichMeterSpec(unitID: unit.id, level: .partialSynthesis, series: series, options: options,
                                                        correctIndex: options.firstIndex(of: meter.id)!, tempo: tempo)))
            }
            if open(.compositeSynthesis) {
                if left(.compositeSynthesis, .meterFromNotation), meterOptions.count >= 2, let series = series(unit, patterns, using: &rng) {
                    let options = meterOptions.shuffled(using: &rng)
                    steps.append(.meterFromNotation(MeterFromNotationSpec(unitID: unit.id, series: series, options: options,
                                                                          correctIndex: options.firstIndex(of: series[0].meter.id)!)))
                }
                if left(.compositeSynthesis, .read, cap: Self.maxUnitAttemptsPerDay * Self.seriesLength),
                   let series = series(unit, patterns, using: &rng) {
                    steps.append(read(series.map { PlannedItem(patternID: $0.id, unitID: unit.id, level: .compositeSynthesis, purpose: .new) },
                                      mode: .evaluation))
                }
            }
        }
        return steps
    }

    /// Four patterns of one of the unit's meters (repeats allowed when the unit has fewer).
    private func series(_ unit: CurriculumUnit, _ patterns: [Pattern], using rng: inout some RandomNumberGenerator) -> [Pattern]? {
        guard let meterID = unit.meters.randomElement(using: &rng) else { return nil }
        let inMeter = patterns.filter { $0.meter.id == meterID }
        guard !inMeter.isEmpty else { return nil }
        return (0..<Self.seriesLength).map { _ in inMeter.randomElement(using: &rng)! }
    }

    /// Practice after the day's work: every pattern already taught, at the unit's current stage
    /// (by ear before AO is passed, with notation after; reading where SA is open). Never counted.
    public func freePractice(_ progress: LearnerProgress, using rng: inout some RandomNumberGenerator) -> SessionPlan {
        var echoes: [PlannedItem] = [], reads: [PlannedItem] = []
        for unit in curriculum.units where Gate.isUnlocked(LevelKey(unitID: unit.id, level: .aural), curriculum: curriculum, passed: progress.passed) {
            let level: SkillLevel = progress.passed.contains(LevelKey(unitID: unit.id, level: .aural)) ? .verbal : .aural
            let reading = Gate.isUnlocked(LevelKey(unitID: unit.id, level: .symbolic), curriculum: curriculum, passed: progress.passed)
            for p in curriculum.patterns(of: unit, in: library) where progress.hasHeard(patternID: p.id) {
                echoes.append(PlannedItem(patternID: p.id, unitID: unit.id, level: level, purpose: .review))
                if reading { reads.append(PlannedItem(patternID: p.id, unitID: unit.id, level: .symbolic, purpose: .review)) }
            }
        }
        guard !echoes.isEmpty else { return SessionPlan(steps: [], frontiers: [], estimatedSeconds: 0) }
        let steps = [holdPulse(progress)].compactMap { $0 }
            + blocksByMeterAndLevel(echoes.shuffled(using: &rng)).map { echo($0, mode: .practice) }
            + blocksByMeterAndLevel(reads.shuffled(using: &rng)).map { read($0, mode: .practice) }
        return SessionPlan(steps: steps, frontiers: [], estimatedSeconds: seconds(steps))
    }

    // MARK: - Review

    private func review(_ progress: LearnerProgress, date: Date, excluding frontiers: Set<LevelKey>) -> [SessionStep] {
        let items: [PlannedItem] = progress.dueItems(on: date).compactMap { state in
            let level = state.key.level
            guard Self.implementedLevels.contains(level), library.pattern(id: state.key.subject) != nil,
                  let unit = curriculum.unit(containing: state.key.subject) else { return nil }
            let key = LevelKey(unitID: unit.id, level: level)
            let passed = progress.passed.contains(key)
            // unpassed reading is practiced by the reading track; the frontier by new material
            guard !frontiers.contains(key), passed || level != .symbolic else { return nil }
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

    private func newMaterial(_ key: LevelKey, progress: LearnerProgress, date: Date, budget: Double, taughtNow: inout Set<String>,
                             using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        guard let unit = curriculum.unit(id: key.unitID) else { return [] }
        let patterns = curriculum.patterns(of: unit, in: library)
        let introduced = patterns.filter { progress.isIntroduced(patternID: $0.id, level: key.level) }
        let startedToday = { (p: Pattern) in progress.teachingStarted(onDayOf: date, patternID: p.id, level: key.level, calendar: calendar) }
        let newSlots = max(0, MasteryPolicy.maxNewPatternsPerDayPerUnit - introduced.filter(startedToday).count)
        // a pattern whose teaching was interrupted today comes first
        let fresh = patterns.filter { !introduced.contains($0) }.sorted { startedToday($0) && !startedToday($1) }.prefix(newSlots)
        let readsUnit = isReading(unit, progress)
        func item(_ p: Pattern, _ level: SkillLevel) -> PlannedItem {
            PlannedItem(patternID: p.id, unitID: unit.id, level: level, purpose: .new)
        }
        func left(_ p: Pattern, _ level: SkillLevel, _ exercise: ExerciseKind) -> Int {
            max(0, MasteryPolicy.maxEvaluationsPerPatternPerDay
                - progress.evaluationsOnDay(of: date, patternID: p.id, level: level, exercise: exercise, calendar: calendar))
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
        var echoes = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, left($0, key.level, .echo)) })
        var questions = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, key.level == .verbal ? left($0, .verbal, .nameNotation) : 0) })
        var reads = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, readsUnit ? left($0, .symbolic, .read) : 0) })
        while seconds(steps) < budget {
            let available = pool.filter { echoes[$0.id]! > 0 }.shuffled(using: &rng)
            var round: [Pattern] = []
            for p in available.sorted(by: { echoes[$0.id]! > echoes[$1.id]! }) {
                round.append(p)
                echoes[p.id]! -= 1
            }
            while !round.isEmpty, round.count < MasteryPolicy.evaluationBlockSize.lowerBound,
                  let p = available.first(where: { echoes[$0.id]! > 0 }) {
                round.append(p)
                echoes[p.id]! -= 1
            }
            var added = blocksByMeterAndLevel(round.shuffled(using: &rng).map { item($0, key.level) }).map { echo($0, mode: .evaluation) }
            for p in pool.shuffled(using: &rng) where questions[p.id]! > 0 {
                questions[p.id]! -= 1
                if let q = nameNotation(item(p, .verbal), pattern: p, using: &rng) { added.append(q) }
            }
            let readable = pool.filter { reads[$0.id]! > 0 && (progress.hasHeard(patternID: $0.id) || taughtNow.contains($0.id)) }
            readable.forEach { reads[$0.id]! -= 1 }
            added += blocksByMeterAndLevel(readable.shuffled(using: &rng).map { item($0, .symbolic) }).map { read($0, mode: .evaluation) }
            guard !added.isEmpty else { break }
            steps += added
        }
        return steps
    }

    /// Reading for earlier units whose ear levels are done but whose reading isn't passed yet.
    private func otherReading(_ progress: LearnerProgress, frontiers: Set<String>, date: Date, budget: Double,
                              using rng: inout some RandomNumberGenerator) -> [SessionStep] {
        let items = curriculum.units.filter { !frontiers.contains($0.id) && isReading($0, progress) }.flatMap { unit in
            curriculum.patterns(of: unit, in: library)
                .filter { progress.hasHeard(patternID: $0.id) }
                .filter {
                    progress.evaluationsOnDay(of: date, patternID: $0.id, level: .symbolic, exercise: .read, calendar: calendar)
                        < MasteryPolicy.maxEvaluationsPerPatternPerDay
                }
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
            clickStage: .forStep(level: level, mode: mode), mode: mode,
            showNotation: level >= .verbal
        ))
    }

    private func read(_ items: [PlannedItem], mode: PracticeMode) -> SessionStep {
        let meter = library.pattern(id: items[0].patternID)!.meter
        return .read(ReadBlockSpec(items: items, meterID: meter.id,
                                   tempo: mode == .teaching ? TempoPolicy.teaching(for: meter) : .standard(for: meter),
                                   clickStage: .forStep(level: items[0].level, mode: mode), mode: mode))
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
        case .echo(let s): return attempts(s.meterID, s.tempo, items: s.items.count, measuresPerAttempt: 2 + s.gapMeasures, mode: s.mode)
        case .read(let s): return attempts(s.meterID, s.tempo, items: s.items.count, measuresPerAttempt: 2, mode: s.mode)
        case .nameNotation, .dictation, .whichMeter, .meterFromNotation: return MasteryPolicy.nameNotationSeconds
        case .holdPulse(let h):
            guard let meter = library.meters[h.meterID] else { return 0 }
            return Double(1 + PulsePolicy.clickedMeasures + h.silentMeasures) * h.tempo.seconds(forTicks: meter.measureTicks, in: meter)
                + MasteryPolicy.stepOverheadSeconds
        }
    }
}
