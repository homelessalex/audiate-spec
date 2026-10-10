import AudiateCore
import SwiftUI

/// A phrase (E13): its measures side by side on one staff, the time signature on the first only, a final
/// barline at the end. With a review: notes vs. taps under every measure, failed measures framed in red.
/// Shrinks to fit the width (StaffLineView). Equatable (by its patterns, without a review) so the per-frame TimelineView
/// doesn't lay it out again every frame.
struct PhraseStaffView: View, Equatable {
    let phrase: [AudiateCore.Pattern]
    var comparisons: [StaffRenderer.Comparison]?
    var measurePassed: [Bool]?

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.comparisons == nil && b.comparisons == nil && a.phrase.map(\.id) == b.phrase.map(\.id)
    }

    var body: some View {
        StaffLineView(patterns: phrase, comparisons: comparisons, measurePassed: measurePassed)
    }
}
