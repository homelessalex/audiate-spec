import AudiateCore
import SwiftUI

/// One pattern on a percussion staff (docs/05-architecture.md §5). Shown only for patterns the learner
/// has already heard and echoed (sound before sight, per pattern).
struct RhythmStaffView: View {
    let pattern: AudiateCore.Pattern
    var zoom: CGFloat = 2
    var showTimeSignature = true
    var beatGrid = false
    var syllables: [String]?
    var currentTick: Double?
    var liveTaps: [Double] = []
    var comparison: StaffRenderer.Comparison?
    var finalBarline = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let layout = try? NotationLayout(pattern: pattern) {
            let renderer = StaffRenderer(layout: layout, pattern: pattern, showTimeSignature: showTimeSignature,
                                         beatGrid: beatGrid, syllables: syllables,
                                         currentTick: currentTick, liveTaps: liveTaps, comparison: comparison,
                                         finalBarline: finalBarline)
            let colors = StaffRenderer.Colors(
                ink: colorScheme == .dark ? CGColor(gray: 0.95, alpha: 1) : CGColor(gray: 0.05, alpha: 1),
                accent: NSColor.controlAccentColor.cgColor,
                muted: CGColor(gray: 0.55, alpha: 1)
            )
            Canvas { context, _ in
                context.scaleBy(x: zoom, y: zoom)
                context.withCGContext { renderer.draw(in: $0, colors: colors) }
            }
            .frame(width: renderer.width * zoom, height: renderer.height * zoom)
            .accessibilityLabel("Notation of \(pattern.id)")
        }
    }
}
