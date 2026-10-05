import AudiateCore
import CoreGraphics
import CoreText
import Foundation

/// Draws a NotationLayout on a one-line percussion staff into a y-down CGContext.
/// All lengths are in layout units; `space` is the staff space in those units.
struct StaffRenderer {
    struct Overlay {
        enum Mark { case good, off, bad }
        /// Measure-relative ticks of the expected onsets.
        var expected: [Double]
        var taps: [(tick: Double, mark: Mark)]
    }

    let layout: NotationLayout
    let pattern: AudiateCore.Pattern
    var space: CGFloat = 8
    var syllables: [String]?
    var playheadTick: Double?
    var overlay: Overlay?

    private var sp: CGFloat { space }
    /// Staff line y; room above for stems, beams and tuplet numbers.
    var staffY: CGFloat { 6 * sp }
    var height: CGFloat { staffY + (overlay != nil ? 6.5 : (syllables != nil ? 4.5 : 2.5)) * sp }
    var width: CGFloat { CGFloat(layout.width) }

    private var stemTop: CGFloat { staffY - 3.5 * sp }
    private let pad: CGFloat = 2

    func draw(in cg: CGContext, ink: CGColor, accent: CGColor, muted: CGColor) {
        guard let font = SMuFL.font(size: 4 * sp) else { return }
        cg.setFillColor(ink)
        cg.setStrokeColor(ink)

        // staff line
        cg.fill(CGRect(x: 0, y: staffY - 0.065 * sp, width: width, height: 0.13 * sp))

        // time signature: numerator above the line, denominator below
        let ts = layout.timeSignature
        drawNumber(ts.beats, at: CGPoint(x: layout.timeSignatureX, y: staffY - sp), font: font, cg: cg)
        drawNumber(ts.beatUnit, at: CGPoint(x: layout.timeSignatureX, y: staffY + sp), font: font, cg: cg)

        for item in layout.items {
            let x = CGFloat(item.x) + pad
            let v = item.notation
            switch item.glyph {
            case .note:
                glyph(v.value == .half ? SMuFL.noteheadHalf : SMuFL.noteheadBlack, at: CGPoint(x: x, y: staffY), font: font, cg: cg)
                let sx = stemX(item)
                cg.fill(CGRect(x: sx, y: stemTop, width: 0.12 * sp, height: staffY - 0.17 * sp - stemTop))
                if item.flagCount > 0 {
                    glyph(item.flagCount == 1 ? SMuFL.flag8thUp : SMuFL.flag16thUp, at: CGPoint(x: sx, y: stemTop), font: font, cg: cg)
                }
                if v.dots > 0 { glyph(SMuFL.augmentationDot, at: CGPoint(x: x + (SMuFL.noteheadWidth + 0.3) * sp, y: staffY - 0.5 * sp), font: font, cg: cg) }
            case .rest:
                let g: UInt32 = switch v.value {
                case .half: SMuFL.restHalf
                case .quarter: SMuFL.restQuarter
                case .eighth: SMuFL.rest8th
                case .sixteenth: SMuFL.rest16th
                }
                glyph(g, at: CGPoint(x: x, y: staffY), font: font, cg: cg)
                if v.dots > 0 { glyph(SMuFL.augmentationDot, at: CGPoint(x: x + 1.4 * sp, y: staffY - 0.5 * sp), font: font, cg: cg) }
            }
        }

        drawBeams(cg)
        for tuplet in layout.tuplets {
            let xs = tuplet.itemIndices.map { stemX(layout.items[$0]) }
            let mid = (xs.min()! + xs.max()!) / 2
            glyph(SMuFL.tuplet3, at: CGPoint(x: mid - 0.55 * sp, y: stemTop - 0.5 * sp), font: font, cg: cg)
        }
        drawTies(cg)
        drawBarlines(cg)

        if let syllables { drawSyllables(syllables, cg: cg, ink: ink, muted: muted) }
        if let overlay { drawOverlay(overlay, cg: cg, muted: muted) }
        if let tick = playheadTick {
            cg.setFillColor(accent)
            cg.fill(CGRect(x: CGFloat(layout.x(forTick: tick)) + pad, y: stemTop - 1.2 * sp, width: 0.18 * sp, height: 5.5 * sp))
        }
    }

    // MARK: - Parts

    private func stemX(_ item: NotationLayout.Item) -> CGFloat {
        CGFloat(item.x) + pad + (SMuFL.noteheadWidth - 0.12) * sp
    }

    private func drawBeams(_ cg: CGContext) {
        let thickness = 0.5 * sp
        for beam in layout.beams {
            let items = beam.itemIndices.map { layout.items[$0] }
            let xs = items.map(stemX)
            cg.fill(CGRect(x: xs.first!, y: stemTop, width: xs.last! + 0.12 * sp - xs.first!, height: thickness))
            // secondary beams for sixteenths: full between neighbours, a stub when alone
            let y2 = stemTop + 0.75 * sp
            for (k, item) in items.enumerated() where item.beamCount >= 2 {
                let nextHas = k + 1 < items.count && items[k + 1].beamCount >= 2
                let prevHas = k > 0 && items[k - 1].beamCount >= 2
                if nextHas {
                    cg.fill(CGRect(x: xs[k], y: y2, width: xs[k + 1] + 0.12 * sp - xs[k], height: thickness))
                } else if !prevHas {
                    let stub = 1.1 * sp
                    let x = k > 0 ? xs[k] - stub + 0.12 * sp : xs[k]
                    cg.fill(CGRect(x: x, y: y2, width: stub, height: thickness))
                }
            }
        }
    }

    private func drawTies(_ cg: CGContext) {
        for tie in layout.ties {
            let a = CGFloat(layout.items[tie.fromItem].x) + pad + 0.8 * sp
            let b = CGFloat(layout.items[tie.toItem].x) + pad + 0.4 * sp
            let y = staffY + 0.7 * sp
            let path = CGMutablePath()
            path.move(to: CGPoint(x: a, y: y))
            path.addQuadCurve(to: CGPoint(x: b, y: y), control: CGPoint(x: (a + b) / 2, y: y + 1.3 * sp))
            path.addQuadCurve(to: CGPoint(x: a, y: y), control: CGPoint(x: (a + b) / 2, y: y + 1.0 * sp))
            cg.addPath(path)
            cg.fillPath()
        }
    }

    private func drawBarlines(_ cg: CGContext) {
        for bar in layout.barlines {
            let x = CGFloat(bar.x)
            let rect = { (x: CGFloat, w: CGFloat) in CGRect(x: x, y: self.staffY - 2 * self.sp, width: w, height: 4 * self.sp) }
            if bar.isFinal {
                cg.fill(rect(x - 0.9 * sp, 0.16 * sp))
                cg.fill(rect(x - 0.5 * sp, 0.5 * sp))
            } else {
                cg.fill(rect(x - 0.08 * sp, 0.16 * sp))
            }
        }
    }

    private func drawSyllables(_ syllables: [String], cg: CGContext, ink: CGColor, muted: CGColor) {
        for (item, text) in zip(layout.items, syllables) {
            let color = item.glyph == .note ? ink : muted
            let center = CGFloat(item.x) + pad + SMuFL.noteheadWidth * sp / 2
            drawText(text, center: CGPoint(x: center, y: staffY + 3.3 * sp), size: 1.7 * sp, color: color, cg: cg)
        }
    }

    private func drawOverlay(_ overlay: Overlay, cg: CGContext, muted: CGColor) {
        let y = staffY + (syllables != nil ? 5.2 : 3.6) * sp
        cg.setFillColor(muted)
        for tick in overlay.expected {
            cg.fill(CGRect(x: CGFloat(layout.x(forTick: tick)) + pad + SMuFL.noteheadWidth * sp / 2 - 0.08 * sp,
                           y: y - 0.9 * sp, width: 0.16 * sp, height: 1.8 * sp))
        }
        for tap in overlay.taps {
            let color: CGColor = switch tap.mark {
            case .good: CGColor(srgbRed: 0.2, green: 0.7, blue: 0.3, alpha: 1)
            case .off: CGColor(srgbRed: 0.95, green: 0.6, blue: 0.1, alpha: 1)
            case .bad: CGColor(srgbRed: 0.9, green: 0.2, blue: 0.2, alpha: 1)
            }
            cg.setFillColor(color)
            let x = CGFloat(layout.x(forTick: tap.tick)) + pad + SMuFL.noteheadWidth * sp / 2
            cg.fillEllipse(in: CGRect(x: x - 0.45 * sp, y: y - 0.45 * sp, width: 0.9 * sp, height: 0.9 * sp))
        }
    }

    // MARK: - Glyphs and text

    private func drawNumber(_ n: Int, at point: CGPoint, font: CTFont, cg: CGContext) {
        var x = point.x
        for ch in String(n) {
            guard let d = ch.wholeNumberValue else { continue }
            glyph(SMuFL.timeSigDigit(d), at: CGPoint(x: x, y: point.y), font: font, cg: cg)
            x += 1.8 * sp
        }
    }

    /// Draws one SMuFL glyph with its baseline origin at `point` (y-down context).
    private func glyph(_ codePoint: UInt32, at point: CGPoint, font: CTFont, cg: CGContext) {
        var chars = Array(String(UnicodeScalar(codePoint)!).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        guard CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count) else { return }
        cg.saveGState()
        cg.translateBy(x: point.x, y: point.y)
        cg.scaleBy(x: 1, y: -1)
        CTFontDrawGlyphs(font, glyphs, [CGPoint.zero], 1, cg)
        cg.restoreGState()
    }

    private func drawText(_ text: String, center: CGPoint, size: CGFloat, color: CGColor, cg: CGContext) {
        let font = CTFontCreateUIFontForLanguage(.system, size, nil)!
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        cg.saveGState()
        cg.translateBy(x: center.x - bounds.width / 2, y: center.y + bounds.height / 3)
        cg.scaleBy(x: 1, y: -1)
        cg.textPosition = .zero
        CTLineDraw(line, cg)
        cg.restoreGState()
    }
}
