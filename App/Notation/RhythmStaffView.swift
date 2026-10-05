import AudiateCore
import SwiftUI

/// One pattern on a percussion staff (docs/05-architecture.md §5). Shown only for patterns the learner
/// has already heard and echoed (sound before sight, per pattern).
struct RhythmStaffView: View {
    let pattern: AudiateCore.Pattern
    var zoom: CGFloat = 2
    var syllables: [String]?
    var playheadTick: Double?
    var overlay: StaffRenderer.Overlay?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let layout = try? NotationLayout(pattern: pattern) {
            let renderer = StaffRenderer(layout: layout, pattern: pattern, syllables: syllables,
                                         playheadTick: playheadTick, overlay: overlay)
            Canvas { context, _ in
                context.scaleBy(x: zoom, y: zoom)
                context.withCGContext { cg in
                    renderer.draw(in: cg, ink: ink, accent: NSColor.controlAccentColor.cgColor,
                                  muted: CGColor(gray: 0.55, alpha: 1))
                }
            }
            .frame(width: renderer.width * zoom, height: renderer.height * zoom)
            .accessibilityLabel("Notation of \(pattern.id)")
        }
    }

    private var ink: CGColor { colorScheme == .dark ? CGColor(gray: 0.95, alpha: 1) : CGColor(gray: 0.05, alpha: 1) }
}
