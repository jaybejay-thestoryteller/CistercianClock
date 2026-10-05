// Simulate how the menu-bar strip will appear: dark macOS menu bar background,
// our image placed at the right edge, next to a mock battery/wifi region.
import AppKit

@main
struct MenuBarMock {
    static func main() {
        let barHeight: CGFloat = NSStatusBar.system.thickness
        let barWidth: CGFloat = 900

        let now = Date()
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let groups = [c.year ?? 0,
                      (c.month ?? 0) * 100 + (c.day ?? 0),
                      (c.hour  ?? 0) * 100 + (c.minute ?? 0),
                      c.second ?? 0]

        let glyphs = CistercianRenderer.image(
            values: groups,
            height: barHeight,
            color: .white,                 // menu bar is dark in dark mode
            gap: barHeight * 0.35
        )

        let out = NSImage(size: NSSize(width: barWidth, height: barHeight))
        out.lockFocusFlipped(true)

        // Dark menu-bar background.
        NSColor(calibratedWhite: 0.12, alpha: 1.0).setFill()
        NSRect(x: 0, y: 0, width: barWidth, height: barHeight).fill()

        // Fake left-side system labels.
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.white
        ]
        ("CistercianClock  File  Edit  View" as NSString).draw(
            at: NSPoint(x: 20, y: (barHeight - 16) / 2),
            withAttributes: labelAttrs
        )

        // Our status item sits to the right.
        let margin: CGFloat = 20
        let x = barWidth - glyphs.size.width - margin
        glyphs.draw(in: NSRect(x: x, y: 0, width: glyphs.size.width, height: glyphs.size.height))

        out.unlockFocus()

        guard let tiff = out.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("encode failed\n", stderr); exit(1)
        }
        try! png.write(to: URL(fileURLWithPath: "build/menubar_mock.png"))
        let desc = "YYYY=\(groups[0])  MM-DD=\(groups[1])  HH:mm=\(groups[2])  SS=\(groups[3])"
        print("wrote build/menubar_mock.png (" + desc + ")")
    }
}
