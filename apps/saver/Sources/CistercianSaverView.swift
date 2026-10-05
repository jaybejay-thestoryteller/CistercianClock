import AppKit
import ScreenSaver

/// Full-screen screen saver that renders the current date and time as four
/// Cistercian glyphs (YYYY / MM-DD / HH:mm / SS), centered and dimly lit.
///
/// Bundle loader resolves the view by class name, so this class is marked
/// `@objc(...)` with the exact name used in Info.plist's `NSPrincipalClass`.
@objc(CistercianSaverView)
final class CistercianSaverView: ScreenSaverView {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }()

    private var lastTick = Date.distantPast

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        // Redraw every second — Cistercian is a seconds-granular format,
        // nothing moves between ticks.
        animationTimeInterval = 1.0
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0
    }

    override func animateOneFrame() {
        // Only trigger a redraw when the second actually rolls over, so the
        // ScreenSaverEngine doesn't do needless work on sub-second ticks.
        let now = Date()
        if Int(now.timeIntervalSinceReferenceDate) != Int(lastTick.timeIntervalSinceReferenceDate) {
            lastTick = now
            setNeedsDisplay(bounds)
        }
    }

    override func draw(_ rect: NSRect) {
        // Dark background — matches the parchment icon's inverted palette.
        NSColor.black.setFill()
        bounds.fill()

        let now = Date()
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let groups: [Int] = [
            c.year  ?? 0,
            (c.month ?? 0) * 100 + (c.day ?? 0),
            (c.hour  ?? 0) * 100 + (c.minute ?? 0),
            c.second ?? 0,
        ]

        // Glyph height tracks the shorter screen dimension so landscape and
        // portrait both look right in System Settings previews.
        let targetHeight = min(bounds.height, bounds.width) * 0.35
        let gap = targetHeight * 0.35
        let ink: NSColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)

        let image = CistercianRenderer.image(
            values: groups,
            height: targetHeight,
            color: ink,
            gap: gap
        )

        // Center within the bounds.
        let drawRect = NSRect(
            x: (bounds.width  - image.size.width)  / 2,
            y: (bounds.height - image.size.height) / 2,
            width: image.size.width,
            height: image.size.height
        )
        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    // No configuration sheet for this version.
    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
