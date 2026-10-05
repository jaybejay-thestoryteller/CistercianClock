import AppKit
import CoreGraphics

/// Draws Cistercian numerals (0-9999) as NSImage suitable for the macOS menu bar.
///
/// Coordinate system per glyph (origin at bottom-left of the glyph bounding box):
///   - stem is a vertical line at x = cx
///   - glyph fits within width w and height h, with cx = w/2
///   - the "ones" quadrant occupies the top-right rectangle
///       (x: cx...cx+armW, y: cy...cy+armH)
///   - other quadrants are mirror-images across the stem and/or the horizontal midline
enum CistercianRenderer {

    struct Metrics {
        let armW: CGFloat   // horizontal arm length per quadrant
        let armH: CGFloat   // vertical arm length per quadrant (half the stem)
        let stroke: CGFloat // line width
        let padding: CGFloat
    }

    /// Build an image that lays out one or more Cistercian numerals in a row.
    /// - Parameters:
    ///   - values: list of numbers (0...9999) to render left-to-right
    ///   - height: target image height in points (menu bar is ~22pt tall)
    ///   - color: stroke color (use `labelColor` for template-like appearance)
    ///   - gap: horizontal gap between consecutive glyphs
    static func image(values: [Int], height: CGFloat, color: NSColor, gap: CGFloat = 6) -> NSImage {
        let m = metrics(forHeight: height)
        let glyphW = m.armW * 2 + m.stroke        // leave room for stroke on both sides
        let glyphH = m.armH * 2 + m.stroke
        let totalW = CGFloat(values.count) * glyphW + CGFloat(max(0, values.count - 1)) * gap + m.padding * 2
        let totalH = glyphH + m.padding * 2

        let size = NSSize(width: totalW, height: totalH)
        let img = NSImage(size: size)
        img.lockFocusFlipped(false)
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return img
        }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(m.stroke)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        var x = m.padding
        for v in values {
            drawGlyph(in: ctx, value: v, originX: x, originY: m.padding, metrics: m)
            x += glyphW + gap
        }

        img.unlockFocus()
        // Not a template image: we picked an explicit color (labelColor adapts to dark/light).
        img.isTemplate = false
        return img
    }

    // MARK: - Metrics

    private static func metrics(forHeight h: CGFloat) -> Metrics {
        // Reserve small vertical padding so strokes aren't clipped by the menu bar.
        let padding: CGFloat = max(1, floor(h * 0.08))
        let glyphH = h - padding * 2
        let stroke: CGFloat = max(1.2, floor(h * 0.08))
        let armH = (glyphH - stroke) / 2        // half of stem length
        let armW = armH * 0.75                   // slightly narrower than tall → classic look
        return Metrics(armW: armW, armH: armH, stroke: stroke, padding: padding)
    }

    // MARK: - Glyph drawing

    private static func drawGlyph(in ctx: CGContext, value raw: Int, originX ox: CGFloat, originY oy: CGFloat, metrics m: Metrics) {
        let value = max(0, min(9999, raw))

        // Center of this glyph's bounding box
        let halfStroke = m.stroke / 2
        let cx = ox + m.armW + halfStroke
        let cyBottom = oy + halfStroke             // y of bottom of stem
        let cyTop = cyBottom + m.armH * 2          // y of top of stem
        let cyMid = (cyTop + cyBottom) / 2

        // Stem — always drawn
        ctx.move(to: CGPoint(x: cx, y: cyBottom))
        ctx.addLine(to: CGPoint(x: cx, y: cyTop))
        ctx.strokePath()

        let ones      = value % 10
        let tens      = (value / 10) % 10
        let hundreds  = (value / 100) % 10
        let thousands = (value / 1000) % 10

        // Four quadrants with (dx, dy) sign flips.
        // ones (top-right):      dx = +1, dy = +1
        // tens (top-left):       dx = -1, dy = +1  (mirror across stem)
        // hundreds (bot-right):  dx = +1, dy = -1  (mirror across horizontal)
        // thousands (bot-left):  dx = -1, dy = -1  (mirror both)
        drawDigit(ones,      ctx: ctx, cx: cx, baseY: cyTop,    cyFar: cyMid, dx: +1, dy: +1, metrics: m)
        drawDigit(tens,      ctx: ctx, cx: cx, baseY: cyTop,    cyFar: cyMid, dx: -1, dy: +1, metrics: m)
        drawDigit(hundreds,  ctx: ctx, cx: cx, baseY: cyBottom, cyFar: cyMid, dx: +1, dy: -1, metrics: m)
        drawDigit(thousands, ctx: ctx, cx: cx, baseY: cyBottom, cyFar: cyMid, dx: -1, dy: -1, metrics: m)
    }

    /// Draw a single digit 0-9 into one quadrant.
    ///
    /// `baseY` is the Y of the stem endpoint on this digit's side (top for upper quadrants, bottom for lower).
    /// `cyFar` is the Y of the mid-stem (the "far" horizontal line of the quadrant).
    /// `dx` is +1 for right side, -1 for left (mirror).
    /// `dy` is +1 for upper half, -1 for lower (mirror).
    ///
    /// Primitive lines (expressed in the top-right ("ones") frame):
    ///   A — top horizontal: from stem-top rightwards
    ///   B — mid horizontal: from stem-mid rightwards (used for 2)
    ///   C — right vertical: top-right corner down to mid-right corner
    ///   D — diagonal ╲ : stem-top to mid-right corner
    ///   E — diagonal ╱ : stem-mid to top-right corner
    ///
    /// Digit → primitive composition (classical Cistercian):
    ///   1 = A
    ///   2 = B
    ///   3 = D
    ///   4 = E
    ///   5 = A + E
    ///   6 = C
    ///   7 = A + C
    ///   8 = B + C
    ///   9 = A + B + C
    private static func drawDigit(_ digit: Int, ctx: CGContext, cx: CGFloat, baseY: CGFloat, cyFar: CGFloat, dx: CGFloat, dy: CGFloat, metrics m: Metrics) {
        guard digit >= 1 && digit <= 9 else { return }

        // Four reference points of the quadrant rectangle.
        let stemBase = CGPoint(x: cx,                        y: baseY)                // stem endpoint on this side
        let stemFar  = CGPoint(x: cx,                        y: cyFar)                // stem mid
        let armBase  = CGPoint(x: cx + dx * m.armW,          y: baseY)                // outer corner near stemBase
        let armFar   = CGPoint(x: cx + dx * m.armW,          y: cyFar)                // outer corner near mid

        // Primitives are stroked individually so they look clean at small sizes.
        func stroke(_ a: CGPoint, _ b: CGPoint) {
            ctx.move(to: a)
            ctx.addLine(to: b)
            ctx.strokePath()
        }

        let A = { stroke(stemBase, armBase) }          // horizontal at base
        let B = { stroke(stemFar, armFar) }            // horizontal at mid
        let C = { stroke(armBase, armFar) }            // vertical far from stem
        let D = { stroke(stemBase, armFar) }           // diagonal ╲ (in top-right frame)
        let E = { stroke(stemFar, armBase) }           // diagonal ╱

        switch digit {
        case 1: A()
        case 2: B()
        case 3: D()
        case 4: E()
        case 5: A(); E()
        case 6: C()
        case 7: A(); C()
        case 8: B(); C()
        case 9: A(); B(); C()
        default: break
        }
    }
}
