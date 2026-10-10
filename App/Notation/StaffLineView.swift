import AppKit
import AudiateCore
import SwiftUI

/// Measures side by side on one staff, drawn into one Canvas and scaled to the width it is given — up to
/// `maxZoom` — in a single layout pass. (Trying zooms with ViewThatFits laid out every candidate: 46 ms
/// for a four-measure review against 4 ms here.) The time signature on the first measure only, a final
/// barline after the last; with a review, notes vs. taps under each measure and failed ones framed in red.
struct StaffLineView: View {
    let patterns: [AudiateCore.Pattern]
    var comparisons: [StaffRenderer.Comparison]?
    var measurePassed: [Bool]?
    var beatGrid = true
    var maxZoom: CGFloat = 2
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let renderers: [StaffRenderer] = patterns.indices.compactMap { i in
            guard let layout = try? NotationLayout(pattern: patterns[i]) else { return nil }
            return StaffRenderer(layout: layout, pattern: patterns[i], showTimeSignature: i == 0, beatGrid: beatGrid,
                                 comparison: comparisons?[i], finalBarline: i == patterns.count - 1)
        }
        let width = max(renderers.map(\.width).reduce(0, +), 1)
        let height = max(renderers.map(\.height).max() ?? 1, 1)
        let colors = StaffRenderer.Colors(
            ink: colorScheme == .dark ? CGColor(gray: 0.95, alpha: 1) : CGColor(gray: 0.05, alpha: 1),
            accent: NSColor.controlAccentColor.cgColor,
            muted: CGColor(gray: 0.55, alpha: 1)
        )
        let failed = measurePassed?.map { !$0 } ?? []
        Canvas { context, size in
            let zoom = size.width / width
            context.scaleBy(x: zoom, y: zoom)
            context.withCGContext { cg in
                var x: CGFloat = 0
                for (i, renderer) in renderers.enumerated() {
                    cg.saveGState()
                    cg.translateBy(x: x, y: 0)
                    renderer.draw(in: cg, colors: colors)
                    if failed.indices.contains(i), failed[i] {
                        let inset = 1.5 / zoom
                        cg.setStrokeColor(StaffRenderer.Colors.bad)
                        cg.setLineWidth(2.5 / zoom)
                        cg.addPath(CGPath(roundedRect: CGRect(x: inset, y: inset, width: renderer.width - 2 * inset, height: height - 2 * inset),
                                          cornerWidth: 6 / zoom, cornerHeight: 6 / zoom, transform: nil))
                        cg.strokePath()
                    }
                    cg.restoreGState()
                    x += renderer.width
                }
            }
        }
        .aspectRatio(width / height, contentMode: .fit)
        .frame(maxWidth: width * maxZoom)
        .accessibilityLabel("Notation of " + patterns.map(\.id).joined(separator: ", "))
    }
}
