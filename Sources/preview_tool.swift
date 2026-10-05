// Standalone CLI preview: renders a strip of test numerals + the current time
// into build/preview.png so we can visually verify the glyphs.
// Build:
//   swiftc -O -sdk <SDK> -target arm64-apple-macos12.0 -framework AppKit \
//     -o build/preview Sources/CistercianRenderer.swift Sources/preview_tool.swift
import AppKit

@main
struct PreviewTool {
    static func main() {
        // One strip: digits 1..9 so each primitive shape is visible, then 1234, 5678, 9999.
        let digitSamples = Array(1...9)
        let composite = [1234, 5678, 9999, 1005, 2131, 42]

        let strip1 = CistercianRenderer.image(values: digitSamples, height: 64, color: .black, gap: 14)
        let strip2 = CistercianRenderer.image(values: composite,    height: 96, color: .black, gap: 20)

        // Current time groups (same encoding as the menu-bar app).
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let groups = [c.year ?? 0,
                      (c.month ?? 0) * 100 + (c.day ?? 0),
                      (c.hour  ?? 0) * 100 + (c.minute ?? 0),
                      c.second ?? 0]
        let strip3 = CistercianRenderer.image(values: groups, height: 96, color: .black, gap: 24)

        let w = max(strip1.size.width, strip2.size.width, strip3.size.width) + 40
        let h = strip1.size.height + strip2.size.height + strip3.size.height + 80
        let out = NSImage(size: NSSize(width: w, height: h))
        out.lockFocusFlipped(true)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: w, height: h).fill()

        // Draw each strip + a caption underneath (flipped coord: y grows downward).
        func drawCaption(_ s: String, atY y: CGFloat) {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.darkGray
            ]
            (s as NSString).draw(at: NSPoint(x: 20, y: y), withAttributes: attrs)
        }

        var y: CGFloat = 10
        drawCaption("digits 1..9", atY: y); y += 16
        strip1.draw(in: NSRect(x: 20, y: y, width: strip1.size.width, height: strip1.size.height))
        y += strip1.size.height + 10
        drawCaption("composites: 1234, 5678, 9999, 1005, 2131, 42", atY: y); y += 16
        strip2.draw(in: NSRect(x: 20, y: y, width: strip2.size.width, height: strip2.size.height))
        y += strip2.size.height + 10
        let desc = "now groups → YYYY=\(groups[0]), MM-DD=\(groups[1]), HH:mm=\(groups[2]), SS=\(groups[3])"
        drawCaption(desc, atY: y); y += 16
        strip3.draw(in: NSRect(x: 20, y: y, width: strip3.size.width, height: strip3.size.height))

        out.unlockFocus()

        guard let tiff = out.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("failed to encode PNG\n", stderr); exit(1)
        }
        let url = URL(fileURLWithPath: "build/preview.png")
        try! png.write(to: url)
        print("wrote \(url.path)")
    }
}
