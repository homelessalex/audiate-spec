import AudiateCore
import SwiftUI

/// Visual check of the comparison rows and the reading frame (see ContactSheet.exportFeedback).
struct FeedbackSheet: View {
    let library: PatternLibrary

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(Self.cases, id: \.id) { c in
                if let p = library.pattern(id: c.id) {
                    VStack(alignment: .leading) {
                        Text(c.title).font(.system(size: 12, weight: .semibold, design: .monospaced))
                        RhythmStaffView(pattern: p, zoom: 1.7, beatGrid: true, comparison: comparison(p, shifts: c.shifts, extra: c.extra))
                    }
                }
            }
            if let p = library.pattern(id: "D-DV-01") {
                Text("Reading frame: cursor at tick 15, two live taps").font(.system(size: 12, weight: .semibold, design: .monospaced))
                RhythmStaffView(pattern: p, beatGrid: true, currentTick: 15, liveTaps: [0.4, 6.8])
            }
        }
        .padding(24)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    /// Per expected onset: seconds to shift the tap, or nil for a miss.
    struct Case {
        let id: String
        let title: String
        let shifts: [Double?]
        let extra: Double?
    }

    static let cases = [
        Case(id: "D-MM-04", title: "D-MM-04: all on time", shifts: [0.005, -0.01, 0.0, 0.012], extra: nil),
        Case(id: "D-DV-03", title: "D-DV-03: 2nd late +45 ms, 4th missed", shifts: [0.0, 0.045, -0.01, nil, 0.0], extra: nil),
        Case(id: "T-EL-01", title: "T-EL-01: early −60 ms on 2nd, an extra tap", shifts: [0.01, -0.06, 0.0], extra: 1.7),
    ]

    private func comparison(_ p: AudiateCore.Pattern, shifts: [Double?], extra: Double?) -> StaffRenderer.Comparison? {
        let tempo = Tempo.standard(for: p.meter)
        guard let t = try? Timeline.echoBlock(patterns: [p], tempo: tempo, clickStage: .b), let slot = t.responses.first else { return nil }
        var taps = zip(slot.expectedOnsets, shifts).compactMap { e, s in s.map { e + $0 } }
        if let extra { taps.append(slot.end - t.measureDuration + extra * t.measureDuration / 2) }
        let grade = OnsetGrader.grade(expected: slot.expectedOnsets, taps: taps.sorted(), responseStart: slot.start,
                                      responseEnd: slot.end, mode: .absolute)
        return SessionRunner.comparison(grade, pattern: p, downbeat: slot.end - t.measureDuration, tempo: tempo)
    }
}
