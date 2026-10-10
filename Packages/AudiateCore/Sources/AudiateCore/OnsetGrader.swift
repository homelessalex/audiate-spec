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
        var fit: RelativeFit?
        if mode == .relative {
            let f = relativeFit(expected: e, taps: t, origin: responseStart, measure: responseEnd - responseStart, tolerance: tol)
            mapped = t.map { responseStart + ($0 - responseStart - f.b) / f.a }
            tempoRatio = f.ratio
            fit = f
        }

        let pairs = match(expected: e, taps: mapped, tolerance: tol)
        // relative mode: each note against the pulse the *other* notes imply (leave-one-out), so the fit
        // cannot hide a note's own error
        let hits = pairs.map { p in
            OnsetGrade.Hit(expected: e[p.e], tap: t[p.t], error: (mapped[p.t] - e[p.e]) * (fit?.looFactor(e[p.e] - responseStart) ?? 1))
        }
        let matchedE = Set(pairs.map(\.e)), matchedT = Set(pairs.map(\.t))
        let misses = e.indices.filter { !matchedE.contains($0) }.map { e[$0] }
        let extras = t.indices.filter { !matchedT.contains($0) }.map { t[$0] }
        let errors = hits.map { abs($0.error) }
        let mean = errors.isEmpty ? 0 : errors.reduce(0, +) / Double(errors.count)
        let maxError = errors.max() ?? 0

        let drifted = tempoRatio.map { abs(1 - $0) > OnsetGraderPolicy.maxTempoDrift } ?? false
        let passed = !hits.isEmpty && misses.isEmpty && extras.isEmpty
            && maxError <= tol && mean <= OnsetGraderPolicy.maxMeanErrorFraction * tol && !drifted
        return OnsetGrade(hits: hits, misses: misses, extras: extras, meanAbsError: mean, maxAbsError: maxError,
                          tempoRatio: tempoRatio, drifted: drifted, tolerance: tol, passed: passed,
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

    /// The learner's own tempo (`a`) and phase (`b`) in relative mode: `t = a·e + b`, times from the origin.
    struct RelativeFit {
        let a: Double
        let b: Double
        /// Plain least-squares tempo, for the drift rule and the report: the regularized `a` is pulled
        /// toward 1 on purpose and would let a real 10 % change through.
        var ratio: Double = 1
        /// Normal-equation matrix [[p, q], [q, s]] of the ridge fit, for leverages; nil when nothing was fitted.
        var matrix: (p: Double, q: Double, s: Double)?
        /// Expected times (from the origin) that took part in the fit.
        var fitted: [Double] = []

        /// Turns a residual into a leave-one-out error: r / (1 − h), h = the note's leverage on the fit.
        func looFactor(_ x: Double) -> Double {
            guard let m = matrix, fitted.contains(where: { abs($0 - x) < 1e-9 }) else { return 1 }
            let det = m.p * m.s - m.q * m.q
            let h = (m.s * x * x - 2 * m.q * x + m.p) / det
            return 1 / max(1 - h, 0.05)
        }
    }

    /// Fits `t = a·e + b` (times relative to `origin`) on a preliminary matching made after aligning the
    /// first tap with the first expected onset. Regularized toward `a = 1, b = 0` (no drift, no offset):
    /// a plain least-squares fit has two free parameters, so it matches two taps exactly and most of three,
    /// and the error left over would read near zero however uneven the taps were.
    static func relativeFit(expected e: [Double], taps t: [Double], origin: Double, measure: Double,
                            tolerance: Double) -> RelativeFit {
        guard let t0 = t.first, let e0 = e.first else { return RelativeFit(a: 1, b: 0) }
        let shift = t0 - e0
        let prelim = match(expected: e, taps: t.map { $0 - shift }, tolerance: 2 * tolerance)
        guard !prelim.isEmpty else { return RelativeFit(a: 1, b: 0) }
        let x = prelim.map { e[$0.e] - origin }
        let r = prelim.map { t[$0.t] - e[$0.e] }   // error before the fit
        // minimise Σ(r − u·x − b)² + λu·u² + λb·b² with u = a − 1 (ridge; priors in OnsetGraderPolicy)
        let spread = OnsetGraderPolicy.relativeTapSpread
        let du = spread / OnsetGraderPolicy.relativeTempoSpread, db = spread / OnsetGraderPolicy.relativeOffset
        let lu = du * du, lb = db * db
        let sx = x.reduce(0, +), sxx = x.map { $0 * $0 }.reduce(0, +)
        let sr = r.reduce(0, +), sxr = zip(x, r).map { $0 * $1 }.reduce(0, +)
        let p = sxx + lu, q = sx, s = Double(x.count) + lb
        let det = p * s - q * q
        guard det > 0 else { return RelativeFit(a: 1, b: 0) }
        let u = (sxr * s - q * sr) / det
        let b = (p * sr - q * sxr) / det
        let range = OnsetGraderPolicy.relativeSlopeRange
        let clamp = { (a: Double) in min(max(a, range.lowerBound), range.upperBound) }
        return RelativeFit(a: clamp(1 + u), b: b, ratio: clamp(plainSlope(x: x, r: r)), matrix: (p, q, s), fitted: x)
    }

    /// 1 + least-squares slope of the errors `r` over the times `x`; 1 when there is no spread to fit.
    static func plainSlope(x: [Double], r: [Double]) -> Double {
        let n = Double(x.count)
        guard x.count >= 2 else { return 1 }
        let mx = x.reduce(0, +) / n, mr = r.reduce(0, +) / n
        let sxx = x.map { ($0 - mx) * ($0 - mx) }.reduce(0, +)
        guard sxx > 0 else { return 1 }
        return 1 + zip(x, r).map { ($0 - mx) * ($1 - mr) }.reduce(0, +) / sxx
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
