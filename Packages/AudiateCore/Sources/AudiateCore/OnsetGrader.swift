/// Grades tapped onsets against expected onsets (docs/04-exercises.md §2). Deterministic and pure.
public enum OnsetGrader {
    public static func tolerance(expected: [Double], responseStart: Double, responseEnd: Double) -> Double {
        let ioi = minIOI(expected.sorted(), fallback: responseEnd - responseStart)
        return min(max(OnsetGraderPolicy.toleranceFraction * ioi, OnsetGraderPolicy.minTolerance), OnsetGraderPolicy.maxTolerance)
    }

    public static func grade(expected: [Double], taps: [Double], responseStart: Double, responseEnd: Double,
                             mode: TimingMode) -> OnsetGrade {
        let e = expected.sorted()
        let ioi = minIOI(e, fallback: responseEnd - responseStart)
        let pre = min(OnsetGraderPolicy.maxPreWindow, OnsetGraderPolicy.preWindowFraction * ioi)
        let tol = tolerance(expected: e, responseStart: responseStart, responseEnd: responseEnd)
        let t = debounce(taps.sorted()).filter { $0 >= responseStart - pre && $0 < responseEnd - pre }

        var mapped = t
        var tempoRatio: Double?
        if mode == .relative {
            let fit = relativeFit(expected: e, taps: t, origin: responseStart, tolerance: tol)
            mapped = t.map { responseStart + ($0 - responseStart - fit.b) / fit.a }
            tempoRatio = fit.a
        }

        let pairs = match(expected: e, taps: mapped, tolerance: tol)
        let hits = pairs.map { OnsetGrade.Hit(expected: e[$0.e], tap: t[$0.t], error: mapped[$0.t] - e[$0.e]) }
        let matchedE = Set(pairs.map(\.e)), matchedT = Set(pairs.map(\.t))
        let misses = e.indices.filter { !matchedE.contains($0) }.map { e[$0] }
        let extras = t.indices.filter { !matchedT.contains($0) }.map { t[$0] }
        let errors = hits.map { abs($0.error) }
        let mean = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)
        let maxError = errors.max() ?? 0

        var passed = !hits.isEmpty && misses.isEmpty && extras.isEmpty
            && maxError <= tol && mean <= OnsetGraderPolicy.maxMeanErrorFraction * tol
        if let a = tempoRatio, abs(1 - a) > OnsetGraderPolicy.maxTempoDrift {
            passed = false
        }
        return OnsetGrade(hits: hits, misses: misses, extras: extras, meanAbsError: mean, maxAbsError: maxError,
                          tempoRatio: tempoRatio, tolerance: tol, passed: passed,
                          accuracy: Double(hits.count) / Double(max(1, e.count + extras.count)))
    }

    static func minIOI(_ sorted: [Double], fallback: Double) -> Double {
        zip(sorted, sorted.dropFirst()).map { $1 - $0 }.min() ?? fallback
    }

    static func debounce(_ sorted: [Double]) -> [Double] {
        var kept: [Double] = []
        for tap in sorted where kept.last.map({ tap - $0 >= OnsetGraderPolicy.debounce }) ?? true {
            kept.append(tap)
        }
        return kept
    }

    /// Fits `t = a·e + b` (times relative to `origin`) on a preliminary matching made after
    /// aligning the first tap with the first expected onset.
    static func relativeFit(expected e: [Double], taps t: [Double], origin: Double, tolerance: Double) -> (a: Double, b: Double) {
        guard let t0 = t.first, let e0 = e.first else { return (1, 0) }
        let shift = t0 - e0
        let prelim = match(expected: e, taps: t.map { $0 - shift }, tolerance: 2 * tolerance)
        let x = prelim.map { e[$0.e] - origin }
        let y = prelim.map { t[$0.t] - origin }
        let n = Double(x.count)
        guard x.count >= 2 else { return (1, shift) }
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        let sxx = x.map { ($0 - mx) * ($0 - mx) }.reduce(0, +)
        let sxy = zip(x, y).map { ($0 - mx) * ($1 - my) }.reduce(0, +)
        guard sxx > 0 else { return (1, my - mx) }
        let range = OnsetGraderPolicy.relativeSlopeRange
        let a = min(max(sxy / sxx, range.lowerBound), range.upperBound)
        return (a, my - a * mx)
    }

    struct Pair: Hashable {
        let e: Int
        let t: Int
    }

    /// Monotonic assignment with the most pairs, then the smallest Σ|t − e|; pairs only within tolerance.
    static func match(expected e: [Double], taps t: [Double], tolerance: Double) -> [Pair] {
        let n = e.count, m = t.count
        // best[i][j] = (pairs, error) for e[i...] and t[j...]
        var count = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        var error = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        func better(_ c1: Int, _ e1: Double, than c2: Int, _ e2: Double) -> Bool {
            c1 > c2 || (c1 == c2 && e1 < e2)
        }
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                var c = count[i + 1][j], err = error[i + 1][j]
                if better(count[i][j + 1], error[i][j + 1], than: c, err) {
                    c = count[i][j + 1]; err = error[i][j + 1]
                }
                let d = abs(t[j] - e[i])
                if d <= tolerance, better(count[i + 1][j + 1] + 1, error[i + 1][j + 1] + d, than: c, err) {
                    c = count[i + 1][j + 1] + 1; err = error[i + 1][j + 1] + d
                }
                count[i][j] = c
                error[i][j] = err
            }
        }
        var pairs: [Pair] = []
        var i = 0, j = 0
        while i < n, j < m {
            let d = abs(t[j] - e[i])
            if d <= tolerance, count[i][j] == count[i + 1][j + 1] + 1, error[i][j] == error[i + 1][j + 1] + d {
                pairs.append(Pair(e: i, t: j)); i += 1; j += 1
            } else if count[i][j] == count[i + 1][j], error[i][j] == error[i + 1][j] {
                i += 1
            } else {
                j += 1
            }
        }
        return pairs
    }
}
