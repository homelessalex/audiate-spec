/// What the audio thread plays, as one snapshot (docs/05-architecture.md §3): the sounds decided so far,
/// and how the pulse goes on past them. The audio renders on its own, never waiting for the UI: past
/// `decidedUntil` it keeps clicking the `continuation`, and whatever is decided later is placed after
/// the point the audio has reached (FlowSequencer and PulseTrainer take that point as `notBefore`).
public struct StreamPlan: Hashable, Sendable {
    /// Sorted by time.
    public let sounds: [ScheduledSound]
    /// Sounds before this time are final; later ones come from `continuation` until the next plan.
    public let decidedUntil: Double
    /// Nothing starts at or after this time; nil = open-ended.
    public let endTime: Double?
    /// The click past `decidedUntil` (nil = silence).
    public let continuation: ClickContinuation?

    public init(sounds: [ScheduledSound], decidedUntil: Double, endTime: Double?, continuation: ClickContinuation?) {
        self.sounds = sounds.enumerated().sorted { ($0.element.time, $0.offset) < ($1.element.time, $1.offset) }.map(\.element)
        self.decidedUntil = decidedUntil
        self.endTime = endTime
        self.continuation = continuation
    }

    /// Sounds starting in `[from, to)`; nil once the stream has ended.
    public func sounds(from: Double, to: Double) -> [ScheduledSound]? {
        if let endTime, from >= endTime { return nil }
        let end = min(to, endTime ?? .infinity)
        let decidedEnd = min(end, decidedUntil)
        var out: [ScheduledSound] = []
        if from < decidedEnd {
            var i = firstIndex(atOrAfter: from)
            while i < sounds.count, sounds[i].time < decidedEnd {
                out.append(sounds[i])
                i += 1
            }
        }
        if let continuation, end > max(from, decidedUntil) {
            out += continuation.sounds(from: max(from, decidedUntil), to: end)
        }
        return out
    }

    private func firstIndex(atOrAfter time: Double) -> Int {
        var lo = 0, hi = sounds.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if sounds[mid].time < time { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

/// A measure's clicks repeated on the measure grid: what the audio plays when nothing newer is decided.
public struct ClickContinuation: Hashable, Sendable {
    /// Start of a measure of the grid.
    public let gridStart: Double
    public let measure: Double
    /// Clicks of one measure, times relative to its start.
    public let clicks: [ScheduledSound]

    public init(gridStart: Double, measure: Double, clicks: [ScheduledSound]) {
        self.gridStart = gridStart
        self.measure = measure
        self.clicks = clicks
    }

    /// The clicks of one measure starting at `start`.
    public func measureClicks(at start: Double) -> [ScheduledSound] {
        clicks.map { $0.shifted(by: start) }
    }

    func sounds(from: Double, to: Double) -> [ScheduledSound] {
        guard measure > 0, !clicks.isEmpty, to > from else { return [] }
        var k = ((from - gridStart) / measure).rounded(.down) - 1
        var out: [ScheduledSound] = []
        while gridStart + k * measure < to {
            for click in measureClicks(at: gridStart + k * measure) where click.time >= from && click.time < to {
                out.append(click)
            }
            k += 1
        }
        return out
    }
}
