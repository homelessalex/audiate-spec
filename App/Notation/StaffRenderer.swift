import AudiateCore
import CoreGraphics
import CoreText
import Foundation

/// Draws a NotationLayout on a one-line percussion staff into a y-down CGContext, with optional
/// beat grid, syllables, playhead, live taps and a "pattern vs. you" comparison underneath.
/// All lengths are in layout units; `space` is the staff space in those units.
struct StaffRenderer {
    /// What the learner tapped against what the pattern asks for, in measure ticks.
    struct Comparison {
        enum Mark { case good, off, bad }
        struct Hit {
            let expected: Double
            let tap: Double
            let errorMs: Int
            let mark: Mark
        }

        /// Sounding span of each note (ties merged).
        var notes: [(start: Double, end: Double)]
        var hits: [Hit]
        var misses: [Double]
        var extras: [Double]
    }

    struct Colors {
        let ink: CGColor
        let accent: CGColor
        let muted: CGColor
        static let good = CGColor(srgbRed: 0.20, green: 0.68, blue: 0.30, alpha: 1)
        static let off = CGColor(srgbRed: 0.95, green: 0.58, blue: 0.10, alpha: 1)
        static let bad = CGColor(srgbRed: 0.88, green: 0.20, blue: 0.20, alpha: 1)
    }

    let layout: NotationLayout
    let pattern: AudiateCore.Pattern
    var space: CGFloat = 8
    var showTimeSignature = true
    var beatGrid = false
    var syllables: [String]?
    /// Sounding position: draws a playhead, lights the current note and beat.
    var currentTick: Double?
    /// Taps so far, in measure ticks (live feedback while reading).
    var liveTaps: [Double] = []
    var comparison: Comparison?

    private var sp: CGFloat { space }
    /// Staff line y; room above for stems, beams and tuplet numbers.
    var staffY: CGFloat { 6 * sp }
    var width: CGFloat { CGFloat(layout.width) }
    private var stemTop: CGFloat { staffY - 3.5 * sp }
    private let pad: CGFloat = 2

    // Rows under the staff (ties occupy the first 2 spaces).
    private var gridY: CGFloat { staffY + 2.8 * sp }
    private var syllableY: CGFloat { staffY + (beatGrid ? 5.0 : 3.3) * sp }
    private var comparisonTop: CGFloat { (syllables != nil ? syllableY + 1.6 * sp : (beatGrid ? gridY + 1.6 * sp : staffY + 2.4 * sp)) }
    var height: CGFloat {
        if comparison != nil { return comparisonTop + 8.4 * sp }
        if syllables != nil { return syllableY + 1.2 * sp }
        return (beatGrid ? gridY + 1.2 * sp : staffY + 2.5 * sp)
    }

    func draw(in cg: CGContext, colors: Colors) {
        guard let font = SMuFL.font(size: 4 * sp) else { return }
        cg.setFillColor(colors.ink)

        cg.fill(CGRect(x: 0, y: staffY - 0.065 * sp, width: width, height: 0.13 * sp))
        if showTimeSignature {
            let ts = layout.timeSignature
            drawNumber(ts.beats, at: CGPoint(x: layout.timeSignatureX, y: staffY - sp), font: font, cg: cg)
            drawNumber(ts.beatUnit, at: CGPoint(x: layout.timeSignatureX, y: staffY + sp), font: font, cg: cg)
        }

        if let currentTick, let lit = litItem(at: currentTick) {
            // soft band behind the note that sounds now
            let item = layout.items[lit]
            cg.setFillColor(colors.accent.copy(alpha: 0.15)!)
            cg.fill(CGRect(x: CGFloat(item.x), y: stemTop - 0.8 * sp, width: CGFloat(item.slotWidth), height: 5.6 * sp))
        }

        for (index, item) in layout.items.enumerated() {
            let lit = currentTick.flatMap(litItem(at:)) == index
            cg.setFillColor(lit ? colors.accent : colors.ink)
            drawItem(item, font: font, cg: cg)
        }
        cg.setFillColor(colors.ink)
        drawBeams(cg)
        for tuplet in layout.tuplets {
            let xs = tuplet.itemIndices.map { stemX(layout.items[$0]) }
            glyph(SMuFL.tuplet3, at: CGPoint(x: (xs.min()! + xs.max()!) / 2 - 0.55 * sp, y: stemTop - 0.5 * sp), font: font, cg: cg)
        }
        drawTies(cg)
        drawBarlines(cg)

        if beatGrid { drawBeatGrid(cg, colors: colors) }
        if let syllables { drawSyllables(syllables, cg: cg, colors: colors) }
        if let comparison { drawComparison(comparison, cg: cg, colors: colors) }

        if !liveTaps.isEmpty {
            cg.setFillColor(colors.accent)
            for tick in liveTaps {
                let x = noteCenterX(tick)
                cg.fillEllipse(in: CGRect(x: x - 0.4 * sp, y: staffY + 1.7 * sp, width: 0.8 * sp, height: 0.8 * sp))
            }
        }
        if let tick = currentTick {
            cg.setFillColor(colors.accent)
            cg.fill(CGRect(x: noteCenterX(tick) - 0.09 * sp, y: stemTop - 1.2 * sp, width: 0.18 * sp, height: gridY - stemTop + 2 * sp))
        }
    }

    // MARK: - Notes

    private func drawItem(_ item: NotationLayout.Item, font: CTFont, cg: CGContext) {
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
            if v.dots > 0 {
                glyph(SMuFL.augmentationDot, at: CGPoint(x: x + (SMuFL.noteheadWidth + 0.3) * sp, y: staffY - 0.5 * sp), font: font, cg: cg)
            }
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

    /// The note (not rest) sounding at `tick`, ties included.
    private func litItem(at tick: Double) -> Int? {
        guard let index = layout.items.lastIndex(where: { Double($0.startTick) <= tick }),
              tick < Double(layout.items[index].startTick + layout.items[index].ticks) else { return nil }
        var i = index
        while i > 0, pattern.events[i].kind == .continuation { i -= 1 }
        return layout.items[i].glyph == .note ? index : nil
    }

    private func stemX(_ item: NotationLayout.Item) -> CGFloat {
        CGFloat(item.x) + pad + (SMuFL.noteheadWidth - 0.12) * sp
    }

    /// x of a tick, at notehead center (taps and beats line up with the noteheads).
    private func noteCenterX(_ tick: Double) -> CGFloat {
        CGFloat(layout.x(forTick: tick)) + pad + SMuFL.noteheadWidth * sp / 2
    }

    private func drawBeams(_ cg: CGContext) {
        let thickness = 0.5 * sp
        for beam in layout.beams {
            let items = beam.itemIndices.map { layout.items[$0] }
            let xs = items.map(stemX)
            cg.fill(CGRect(x: xs.first!, y: stemTop, width: xs.last! + 0.12 * sp - xs.first!, height: thickness))
            let y2 = stemTop + 0.75 * sp
            for (k, item) in items.enumerated() where item.beamCount >= 2 {
                let nextHas = k + 1 < items.count && items[k + 1].beamCount >= 2
                let prevHas = k > 0 && items[k - 1].beamCount >= 2
                if nextHas {
                    cg.fill(CGRect(x: xs[k], y: y2, width: xs[k + 1] + 0.12 * sp - xs[k], height: thickness))
                } else if !prevHas {
                    let stub = 1.1 * sp
                    cg.fill(CGRect(x: k > 0 ? xs[k] - stub + 0.12 * sp : xs[k], y: y2, width: stub, height: thickness))
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

    // MARK: - Beat grid, syllables

    /// Macrobeats tall, microbeats short, at their place under the notes; the current one lights up.
    private func drawBeatGrid(_ cg: CGContext, colors: Colors) {
        let tpm = Rhythm.ticksPerMicrobeat
        var current: Int?
        if let t = currentTick { current = Int((t / Double(tpm)).rounded(.down)) * tpm }
        for span in pattern.meter.macrobeatSpans {
            for micro in 0..<span.microbeats {
                let tick = span.startTick + micro * tpm
                let strong = micro == 0
                let lit = current == tick
                cg.setFillColor(lit ? colors.accent : colors.muted)
                let h = (strong ? 1.1 : 0.6) * sp
                let w = (strong ? 0.5 : 0.3) * sp
                cg.fill(CGRect(x: noteCenterX(Double(tick)) - w / 2, y: gridY - h / 2, width: w, height: h))
            }
        }
    }

    private func drawSyllables(_ syllables: [String], cg: CGContext, colors: Colors) {
        for (item, text) in zip(layout.items, syllables) {
            drawText(text, center: CGPoint(x: noteCenterX(Double(item.startTick)), y: syllableY), size: 1.7 * sp,
                     color: item.glyph == .note ? colors.ink : colors.muted, cg: cg)
        }
    }

    // MARK: - Comparison

    /// Two rows: "notes" (where each note starts and how long it sounds) and "you" (your taps),
    /// each hit joined to its note, with the error in ms when it's noticeable.
    private func drawComparison(_ c: Comparison, cg: CGContext, colors: Colors) {
        // ticks and words are larger than the staff's own detail: this is what the learner reads after a miss
        let tickH = 1.9 * sp, tickW = 0.4 * sp
        let notesY = comparisonTop + 0.9 * sp
        let youY = notesY + 3.6 * sp
        let label = { (text: String, y: CGFloat) in
            self.drawText(text, left: CGPoint(x: 1, y: y), size: 1.45 * self.sp, color: colors.muted, cg: cg)
        }
        label("notes", notesY + 0.45 * sp)
        label("you", youY + 0.5 * sp)
        // one row of words under the taps, left to right; a word that would run into the previous one is
        // left out (its tick still shows), so close notes never print "missedmissed"
        var labels = LabelRow(renderer: self, y: youY + 2.9 * sp, cg: cg)
        defer { labels.flush() }

        for note in c.notes {
            let missed = c.misses.contains(note.start)
            let x0 = noteCenterX(note.start), x1 = max(x0 + 0.8 * sp, noteCenterX(note.end) - 0.5 * sp)
            let bar = CGRect(x: x0, y: notesY, width: x1 - x0, height: 0.9 * sp)
            cg.setFillColor(colors.muted.copy(alpha: 0.35)!)
            cg.fill(bar)
            cg.setFillColor(missed ? Colors.bad : colors.ink)
            cg.fill(CGRect(x: x0 - tickW / 2, y: notesY - 0.5 * sp, width: tickW, height: tickH))
            if missed {
                // an empty tick where the tap should have been
                cg.setStrokeColor(Colors.bad)
                cg.setLineWidth(0.14 * sp)
                cg.stroke(CGRect(x: x0 - tickW * 0.7, y: youY - 0.5 * sp, width: tickW * 1.4, height: tickH))
                labels.draw("missed", at: x0, color: Colors.bad)
            }
        }

        for hit in c.hits {
            let color = hit.mark == .good ? Colors.good : Colors.off
            let xe = noteCenterX(hit.expected), xt = noteCenterX(hit.tap)
            cg.setStrokeColor(color)
            cg.setLineWidth(0.22 * sp)
            cg.move(to: CGPoint(x: xe, y: notesY + 1.4 * sp))
            cg.addLine(to: CGPoint(x: xt, y: youY - 0.5 * sp))
            cg.strokePath()
            cg.setFillColor(color)
            cg.fill(CGRect(x: xt - tickW / 2, y: youY - 0.5 * sp, width: tickW, height: tickH))
            if hit.mark != .good {
                labels.draw(String(format: "%+d", hit.errorMs), at: xt, color: color)
            }
        }
        for tick in c.extras {
            let x = noteCenterX(tick)
            cg.setFillColor(Colors.bad)
            cg.fill(CGRect(x: x - tickW / 2, y: youY - 0.5 * sp, width: tickW, height: tickH))
            labels.draw("extra", at: x, color: Colors.bad)
        }
    }

    /// Words under the comparison taps, drawn in x order without overlapping.
    private struct LabelRow {
        let renderer: StaffRenderer
        let y: CGFloat
        let cg: CGContext
        private var pending: [(text: String, x: CGFloat, color: CGColor)] = []

        init(renderer: StaffRenderer, y: CGFloat, cg: CGContext) {
            self.renderer = renderer
            self.y = y
            self.cg = cg
        }

        mutating func draw(_ text: String, at x: CGFloat, color: CGColor) {
            pending.append((text, x, color))
        }

        func flush() {
            let size = 1.5 * renderer.sp
            var right = -CGFloat.infinity
            for label in pending.sorted(by: { $0.x < $1.x }) {
                let line = StaffRenderer.line(label.text, size: size, color: label.color)
                let width = CTLineGetBoundsWithOptions(line, .useOpticalBounds).width
                guard label.x - width / 2 >= right + 0.4 * renderer.sp else { continue }
                renderer.drawText(label.text, center: CGPoint(x: label.x, y: y), size: size, color: label.color, cg: cg)
                right = label.x + width / 2
            }
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

    /// One SMuFL glyph with its baseline origin at `point` (y-down context).
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
        let line = Self.line(text, size: size, color: color)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        drawLine(line, at: CGPoint(x: center.x - bounds.width / 2, y: center.y + bounds.height / 3), cg: cg)
    }

    private func drawText(_ text: String, left: CGPoint, size: CGFloat, color: CGColor, cg: CGContext) {
        let line = Self.line(text, size: size, color: color)
        let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
        drawLine(line, at: CGPoint(x: left.x, y: left.y + bounds.height / 3), cg: cg)
    }

    private func drawLine(_ line: CTLine, at baseline: CGPoint, cg: CGContext) {
        cg.saveGState()
        cg.translateBy(x: baseline.x, y: baseline.y)
        cg.scaleBy(x: 1, y: -1)
        cg.textPosition = .zero
        CTLineDraw(line, cg)
        cg.restoreGState()
    }

    private static func line(_ text: String, size: CGFloat, color: CGColor) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(.system, size, nil)!
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ]))
    }
}
