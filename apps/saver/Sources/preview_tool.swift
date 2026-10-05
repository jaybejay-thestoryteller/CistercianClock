// Standalone preview: renders what CistercianSaverView would draw on a typical
// 1920×1080 display, into build/preview.png. Lets us verify layout without
// installing the .saver bundle.
import AppKit

@main
struct SaverPreview {
    static func main() {
        let size = NSSize(width: 1920, height: 1080)
        let img = NSImage(size: size)
        img.lockFocusFlipped(false)

        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()

        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let groups = [c.year ?? 0,
                      (c.month ?? 0) * 100 + (c.day ?? 0),
                      (c.hour  ?? 0) * 100 + (c.minute ?? 0),
                      c.second ?? 0]

        let targetH = min(size.height, size.width) * 0.35
        let gap = targetH * 0.35
        let ink = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        let glyphs = CistercianRenderer.image(values: groups, height: targetH, color: ink, gap: gap)

        let drawRect = NSRect(
            x: (size.width  - glyphs.size.width)  / 2,
            y: (size.height - glyphs.size.height) / 2,
            width: glyphs.size.width,
            height: glyphs.size.height
        )
        glyphs.draw(in: drawRect)

        img.unlockFocus()

        guard let tiff = img.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff),
              let png  = rep.representation(using: .png, properties: [:]) else {
            fputs("encode failed\n", stderr); exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: "build/preview.png"))
        print("wrote build/preview.png  (groups: \(groups))")
    }
}
