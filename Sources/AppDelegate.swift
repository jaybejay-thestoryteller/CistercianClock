import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var launchAtLoginMenuItem: NSMenuItem!

    // UserDefaults flag — remember if we already auto-enabled login item once,
    // so if the user disables it from the menu, we don't re-enable on next launch.
    private let firstRunKey = "didAutoRegisterLoginItem_v1"

    private let tooltipFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Persist the user's chosen position in the menu bar (⌘-drag).
        // The system remembers it across launches and restarts under this name.
        statusItem.autosaveName = "dev.jaewoos.CistercianClock.statusItem"

        if let button = statusItem.button {
            button.imagePosition = .imageOnly
        }

        buildMenu()
        maybeAutoRegisterLoginItem()

        render()
        scheduleTimer()
    }

    // MARK: - Menu

    private func buildMenu() {
        let menu = NSMenu()

        launchAtLoginMenuItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Cistercian Clock",
                                action: #selector(quit),
                                keyEquivalent: "q"))

        statusItem.menu = menu
        // Refresh the checkmark whenever the menu opens, in case the user changed
        // the Login Items state from System Settings.
        menu.delegate = menuDelegateProxy
    }

    private lazy var menuDelegateProxy: NSMenuDelegate = MenuWillOpenHandler { [weak self] in
        self?.refreshLaunchAtLoginState()
    }

    // MARK: - Login item

    private func maybeAutoRegisterLoginItem() {
        let service = SMAppService.mainApp
        let defaults = UserDefaults.standard
        let didAutoRegister = defaults.bool(forKey: firstRunKey)

        // First-run case: the user has never been auto-opted-in. Register and remember.
        if !didAutoRegister {
            defaults.set(true, forKey: firstRunKey)
            do { try service.register() }
            catch { NSLog("CistercianClock: first-run register failed: \(error)") }
            refreshLaunchAtLoginState()
            return
        }

        // Subsequent runs: if the user kept Launch-at-Login enabled, re-register so
        // the login item's URL tracks this bundle's current path (handy if the user
        // moved the app from the dev build location into /Applications).
        if service.status == .enabled {
            do { try service.register() }
            catch { NSLog("CistercianClock: refresh register failed: \(error)") }
        }
        refreshLaunchAtLoginState()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't update Login Items"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
        refreshLaunchAtLoginState()
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginMenuItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
    }

    // MARK: - Rendering loop

    private func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.render()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func render() {
        let now = Date()
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let yyyy  = comps.year   ?? 0
        let mm    = comps.month  ?? 0
        let dd    = comps.day    ?? 0
        let hh    = comps.hour   ?? 0
        let mi    = comps.minute ?? 0
        let ss    = comps.second ?? 0

        let groups: [Int] = [yyyy, mm * 100 + dd, hh * 100 + mi, ss]

        let height = NSStatusBar.system.thickness
        let image = CistercianRenderer.image(
            values: groups,
            height: height,
            color: .labelColor,
            gap: height * 0.35
        )
        statusItem.button?.image = image
        statusItem.button?.toolTip = tooltipFormatter.string(from: now)
    }
}

// Small shim so we can refresh menu state without making AppDelegate the NSMenuDelegate.
private final class MenuWillOpenHandler: NSObject, NSMenuDelegate {
    private let action: () -> Void
    init(action: @escaping () -> Void) { self.action = action }
    func menuWillOpen(_ menu: NSMenu) { action() }
}
