/// The pulse trainer (E10 as its own practice, docs/04-exercises.md §6): an endless stream of
/// `| click … | silence … | click … | silence … |`. When the click comes back you hear how far you
/// drifted, you settle back in, and try again. The silences adapt to how well the pulse was held.
///
/// Blocks mode: 2 clicked measures, then a silent stretch that grows (2 → 16 measures) while the drift
/// stays small and shrinks when it grows. Random dropouts: the click disappears for 1…n measures at
/// unpredictable places (n grows the same way), like losing your reference in real playing.
///
/// Like FlowSequencer, sounds are laid out ahead of playback; a silent stretch's outcome decides the
/// next one, which starts after at least one clicked measure.
public struct PulseTrainer: Sendable {
    public enum Mode: String, CaseIterable, Hashable, Sendable {
        case blocks
        case randomDropouts
    }

    /// What the learner taps.
    public enum Subdivision: String, CaseIterable, Hashable, Sendable {
        case macrobeats
        case microbeats
        case divisions
    }

    public struct Settings: Hashable, Sendable {
        public var meter: Meter
        public var tempo: Tempo
        public var subdivision: Subdivision
        public var mode: Mode

        public init(meter: Meter, tempo: Tempo, subdivision: Subdivision, mode: Mode) {
            self.meter = meter
            self.tempo = tempo
            self.subdivision = subdivision
            self.mode = mode
        }
    }

    public enum Role: Hashable, Sendable {
        case click
        case silent
    }

    public struct Measure: Hashable, Sendable {
        public let start: Double
        public let duration: Double
        public let role: Role
        /// The silent stretch this measure belongs to (or follows, for clicked ones).
        public let cycle: Int
        /// 1-based position inside its silent stretch.
        public let indexInRun: Int
        public let runLength: Int
        public var end: Double { start + duration }
    }

    /// One silent stretch and the beats expected in it.
    public struct Cycle: Hashable, Sendable {
        public let index: Int
        public let start: Double
        public let end: Double
        public let measures: Int
        public let beats: [Double]
    }

    /// How a silent stretch went.
    public struct Result: Hashable, Sendable {
        public let cycle: Int
        public let measures: Int
        /// Last tap − last beat, seconds (+ late).
        public let driftSeconds: Double
        /// The same as a fraction of a macrobeat.
        public let driftBeats: Double
        /// The tempo the taps implied (macrobeat BPM, or eighths for unusual meters).
        public let tappedBPM: Double
        public let jitter: Double
        public let grade: PulseGrade
    }

    public let settings: Settings
    public private(set) var measures: [Measure] = []
    public private(set) var cycles: [Cycle] = []
    public private(set) var results: [Result] = []
    /// The silent stretch waiting to be graded.
    public private(set) var awaiting: Int?
    /// Index into `Policy.lengths` (blocks) or `Policy.runs` (random dropouts).
    public private(set) var level = 0

    private var sounds: [ScheduledSound] = []
    private var rng: SeededRandomNumberGenerator

    public enum Policy {
        /// Silent stretch lengths in blocks mode.
        public static let lengths = [2, 4, 6, 8, 12, 16]
        /// Longest silent run in random-dropout mode.
        public static let runs = [1, 2, 3, 4]
        public static let clickedMeasures = 2
        /// |drift| below this (fraction of a macrobeat) and steady beats → longer silences.
        public static let goodDrift = 0.05
        /// |drift| above this, or a lost count → shorter silences.
        public static let badDrift = 0.15
    }

    public init(settings: Settings, seed: UInt64 = 1) {
        self.settings = settings
        rng = SeededRandomNumberGenerator(seed: seed)
        appendClicked(Policy.clickedMeasures, cycle: 0)
        appendSilent(cycle: 0)
        appendClicked(nextClickedRun(), cycle: 0)
    }

    public var measureDuration: Double { settings.tempo.seconds(forTicks: settings.meter.measureTicks, in: settings.meter) }

    public func sounds(from: Double, to: Double) -> [ScheduledSound] {
        sounds.filter { $0.time >= from && $0.time < to }
    }

    /// Everything before this time is laid out (the next silence waits for the last one's result).
    public var decidedUntil: Double { measures.last?.end ?? 0 }

    public func measure(at time: Double) -> Measure? {
        measures.last { $0.start <= time && time < $0.end }
    }

    // MARK: - Results

    /// Grades the awaited silent stretch, adapts, and lays out the next one.
    @discardableResult
    public mutating func report(taps: [Double]) -> Result? {
        guard let index = awaiting, cycles.indices.contains(index) else { return nil }
        let cycle = cycles[index]
        let grade = PulseGrader.grade(beats: cycle.beats, taps: taps)
        let inside = taps.sorted().filter { $0 >= cycle.start - 0.2 && $0 < cycle.end }
        let macro = settings.tempo.seconds(forTicks: settings.meter.macrobeatSpans[0].ticks, in: settings.meter)
        let lastBeat = cycle.beats.last ?? cycle.end
        let drift = (inside.last ?? lastBeat) - lastBeat
        let ratio = Self.tempoRatio(beats: cycle.beats, taps: inside)
        let result = Result(cycle: index, measures: cycle.measures, driftSeconds: drift, driftBeats: drift / macro,
                            tappedBPM: settings.tempo.bpm / ratio, jitter: grade.jitter, grade: grade)
        results.append(result)

        let lost = grade.problems.contains(.lostCount)
        let maxLevel = (settings.mode == .blocks ? Policy.lengths.count : Policy.runs.count) - 1
        if !lost, abs(result.driftBeats) < Policy.goodDrift, !grade.problems.contains(.uneven) {
            level = min(level + 1, maxLevel)
        } else if lost || abs(result.driftBeats) > Policy.badDrift {
            level = max(level - 1, 0)
        }
        awaiting = nil
        appendSilent(cycle: index + 1)
        appendClicked(nextClickedRun(), cycle: index + 1)
        return result
    }

    /// Taps per beat: slope of tap times against beat times (in order); > 1 means slower.
    static func tempoRatio(beats: [Double], taps: [Double]) -> Double {
        let n = min(beats.count, taps.count)
        guard n >= 2 else { return 1 }
        let (a, _) = ImprovGrader.fit(x: Array(beats.prefix(n)), y: Array(taps.prefix(n)))
        return a
    }

    // MARK: - Layout

    private var nextStart: Double { measures.last?.end ?? 0 }

    private mutating func nextClickedRun() -> Int {
        settings.mode == .blocks ? Policy.clickedMeasures : Int.random(in: 1...3, using: &rng)
    }

    private mutating func appendClicked(_ count: Int, cycle: Int) {
        for _ in 0..<count {
            let start = nextStart
            measures.append(Measure(start: start, duration: measureDuration, role: .click, cycle: cycle, indexInRun: 0, runLength: 0))
            sounds += FlowSequencer.countInClicks(settings.meter, tempo: settings.tempo, at: start)
        }
    }

    private mutating func appendSilent(cycle: Int) {
        let length = settings.mode == .blocks ? Policy.lengths[level] : Int.random(in: 1...Policy.runs[level], using: &rng)
        let start = nextStart
        for k in 0..<length {
            measures.append(Measure(start: start + Double(k) * measureDuration, duration: measureDuration, role: .silent,
                                    cycle: cycle, indexInRun: k + 1, runLength: length))
        }
        let ticks = gridTicks()
        let beats = (0..<length).flatMap { m in
            ticks.map { start + Double(m) * measureDuration + settings.tempo.seconds(forTicks: $0, in: settings.meter) }
        }
        cycles.append(Cycle(index: cycle, start: start, end: start + Double(length) * measureDuration, measures: length, beats: beats))
        awaiting = cycle
    }

    /// The grid the learner taps.
    func gridTicks() -> [Int] {
        let m = settings.meter
        switch settings.subdivision {
        case .macrobeats: return m.macrobeatSpans.map(\.startTick)
        case .microbeats: return Array(stride(from: 0, to: m.measureTicks, by: Rhythm.ticksPerMicrobeat))
        case .divisions: return Array(stride(from: 0, to: m.measureTicks, by: Rhythm.divisionTicks))
        }
    }
}
