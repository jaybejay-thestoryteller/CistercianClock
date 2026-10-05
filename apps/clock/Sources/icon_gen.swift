// Generates the macOS app iconset (10 PNGs) under build/AppIcon.iconset,
// then the build script runs `iconutil -c icns` to produce AppIcon.icns.
//
// Design: parchment-cream rounded square with a dark Cistercian "2026" glyph
// at the center. Reads well as a silhouette at 16px, and tells the story at
// 512px.
import AppKit

@main
struct IconGen {

    // Color palette — chosen to look like faded medieval manuscript ink on vellum.
    static let parchment = NSColor(calibratedRed: 0.957, green: 0.918, blue: 0.820, alpha: 1.0)
    static let ink       = NSColor(calibratedRed: 0.153, green: 0.090, blue: 0.055, alpha: 1.0)
    static let edge      = NSColor(calibratedRed: 0.824, green: 0.769, blue: 0.651, alpha: 1.0)

    static func main() {
        // Standard macOS iconset sizes (actual pixel dimensions on the left).
        let sizes: [(px: Int, name: String)] = [
            (16,   "icon_16x16.png"),
            (32,   "icon_16x16@2x.png"),
            (32,   "icon_32x32.png"),
            (64,   "icon_32x32@2x.png"),
            (128,  "icon_128x128.png"),
            (256,  "icon_128x128@2x.png"),
            (256,  "icon_256x256.png"),
            (512,  "icon_256x256@2x.png"),
            (512,  "icon_512x512.png"),
            (1024, "icon_512x512@2x.png"),
        ]

        let dir = URL(fileURLWithPath: "build/AppIcon.iconset")
        try? FileManager.default.removeItem(at: dir)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for (px, name) in sizes {
            let img = renderIcon(size: px)
            guard let tiff = img.tiffRepresentation,
                  let rep  = NSBitmapImageRep(data: tiff),
                  let png  = rep.representation(using: .png, properties: [:]) else {
                fputs("encode failed for \(name)\n", stderr); exit(1)
            }
            try! png.write(to: dir.appendingPathComponent(name))
        }
        print("wrote \(sizes.count) PNGs to \(dir.path)")
    }

    /// Build an icon image at the given pixel size.
    static func renderIcon(size px: Int) -> NSImage {
        let side = CGFloat(px)
        let img = NSImage(size: NSSize(width: side, height: side))
        // Use flipped=false so our drawing math matches CistercianRenderer's coordinate system.
        img.lockFocusFlipped(false)
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            img.unlockFocus()
            return img
        }

        // --- Rounded-square plate ---
        // macOS icon template leaves ~10% padding to the canvas edge; its silhouette
        // uses a superellipse but a rounded rect reads nearly identical at every size.
        let inset: CGFloat   = side * 0.08
        let plateR: CGFloat  = side * 0.22
        let plateRect = CGRect(x: inset, y: inset, width: side - 2*inset, height: side - 2*inset)

        // Fill plate.
        let platePath = CGPath(roundedRect: plateRect,
                               cornerWidth: plateR, cornerHeight: plateR, transform: nil)
        ctx.addPath(platePath)
        ctx.setFillColor(parchment.cgColor)
        ctx.fillPath()

        // Subtle warm-shadow rim — gives depth without looking skeuomorphic.
        ctx.addPath(platePath)
        ctx.setStrokeColor(edge.cgColor)
        ctx.setLineWidth(max(1.0, side * 0.006))
        ctx.strokePath()

        // --- Cistercian "2026" glyph ---
        // Reuse the production renderer; strip gap doesn't matter for a single glyph.
        // The renderer paints into a bitmap sized to its height arg, so we need to
        // scale/center it on the plate.
        let glyphCanvasH = side * 0.70     // target glyph height within the plate
        // 1234 — canonical demo numeral in Cistercian references. Each of the four
        // quadrants carries a different primitive shape, so the glyph reads cleanly
        // at every icon size without strokes overlapping on the midline.
        let glyph = CistercianRenderer.image(values: [1234], height: glyphCanvasH, color: ink, gap: 0)

        // Center the glyph image inside the plate.
        let gw = glyph.size.width
        let gh = glyph.size.height
        let gx = (side - gw) / 2
        let gy = (side - gh) / 2
        glyph.draw(in: NSRect(x: gx, y: gy, width: gw, height: gh),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)

        img.unlockFocus()
        return img
    }
}
