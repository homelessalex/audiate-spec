/// Grades E8 "answer differently" (docs/04-exercises.md §5): the taps, snapped to the grid of the
/// unlocked content, must form a different pattern in the same meter while the pulse is held.
public enum ImprovGrader {
    /// `taps` and `downbeat` in seconds (the response measure starts at `downbeat`).
    public static func grade(taps: [Double], prompt: Pattern, downbeat: Double, tempo: Tempo, unlocked: Set<ContentKind>) -> ImprovGrade {
        let meter = prompt.meter
        let spt = tempo.secondsPerTick(in: meter)
        let grid = gridTicks(meter, unlocked: unlocked)
        let step = zip(grid, grid.dropFirst()).map { $1 - $0 }.min() ?? Rhythm.ticksPerMicrobeat
        let tolerance = min(max(OnsetGraderPolicy.toleranceFraction * Double(step) * spt, OnsetGraderPolicy.minTolerance),
                            OnsetGraderPolicy.maxTolerance)
        let pre = min(OnsetGraderPolicy.maxPreWindow, OnsetGraderPolicy.preWindowFraction * Double(step) * spt)
        let measure = Double(meter.measureTicks) * spt
        let inside = OnsetGrader.debounce(taps.sorted()).filter { $0 >= downbeat - pre && $0 < downbeat + measure - pre }
        let ticks = inside.map { ($0 - downbeat) / spt }

        // pulse held: fit tap ticks to their nearest grid points (t = a·g + b) and check the slope
        let nearest = ticks.map { t in grid.min { abs(Double($0) - t) < abs(Double($1) - t) }! }
        let (a, b) = fit(x: nearest.map(Double.init), y: ticks)
        let mapped = ticks.map { ($0 - b) / a }
        let snapped = mapped.map { t in grid.min { abs(Double($0) - t) < abs(Double($1) - t) }! }

        var problems: [ImprovGrade.Problem] = []
        if abs(1 - a) > OnsetGraderPolicy.maxTempoDrift { problems.append(.tempoDrift) }
        if zip(mapped, snapped).contains(where: { abs($0 - Double($1)) * spt > tolerance }) { problems.append(.offGrid) }
        let onsets = Array(Set(snapped)).sorted()
        if onsets.count < 2 { problems.append(.tooFew) }
        if Set(onsets) == Set(prompt.onsets.map(\.startTick)) { problems.append(.sameAsPrompt) }
        return ImprovGrade(quantizedOnsets: onsets, tempoRatio: a, problems: problems)
    }

    /// Grid points of the measure: microbeats, plus divisions if unlocked, plus thirds in the combined meter.
    static func gridTicks(_ meter: Meter, unlocked: Set<ContentKind>) -> [Int] {
        var points = Set(stride(from: 0, to: meter.measureTicks, by: Rhythm.ticksPerMicrobeat))
        if unlocked.contains(.division) { points.formUnion(stride(from: 0, to: meter.measureTicks, by: Rhythm.divisionTicks)) }
        if meter.allowsThirds, unlocked.contains(.combined) {
            for span in meter.macrobeatSpans where span.microbeats == 2 {
                points.formUnion([span.startTick + Rhythm.thirdTicks, span.startTick + 2 * Rhythm.thirdTicks])
            }
        }
        return points.sorted()
    }

    /// Least squares y = a·x + b; identity offset when there aren't two distinct points.
    static func fit(x: [Double], y: [Double]) -> (a: Double, b: Double) {
        let n = Double(x.count)
        guard x.count >= 2 else { return (1, x.isEmpty ? 0 : y[0] - x[0]) }
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        var sxx = 0.0, sxy = 0.0
        for (xi, yi) in zip(x, y) {
            sxx += (xi - mx) * (xi - mx)
            sxy += (xi - mx) * (yi - my)
        }
        guard sxx > 0 else { return (1, my - mx) }
        let range = OnsetGraderPolicy.relativeSlopeRange
        let a = min(max(sxy / sxx, range.lowerBound), range.upperBound)
        return (a, my - a * mx)
    }
}
