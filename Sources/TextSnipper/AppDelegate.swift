import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkeys = HotkeyManager()
    private let shortcutPanel = ShortcutPanelController()
    private var captureItem: NSMenuItem!
    private var lineBreakItem: NSMenuItem!
    private var activity: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if terminateIfAlreadyRunning() {
            return
        }
        ProcessInfo.processInfo.disableAutomaticTermination("TextSnipper stays in the menu bar")
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "TextSnipper stays ready to capture text"
        )
        setupMenuBar()
        hotkeys.onPressed = { [weak self] in
            self?.captureText()
        }
        if !hotkeys.register(SettingsStore.shortcut) {
            showAlert(
                title: "Shortcut not available",
                message: "\(KeyDisplay.shortcutString(SettingsStore.shortcut)) is already used. Choose another shortcut from the TextSnipper menu."
            )
        }
        updateMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "TextSnipper")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        captureItem = NSMenuItem(title: "Capture Text", action: #selector(captureText), keyEquivalent: "")
        captureItem.target = self
        lineBreakItem = NSMenuItem(title: "Keep Line Breaks", action: #selector(toggleLineBreaks), keyEquivalent: "")
        lineBreakItem.target = self
        let shortcutItem = NSMenuItem(title: "Change Shortcut…", action: #selector(changeShortcut), keyEquivalent: "")
        shortcutItem.target = self
        let quitItem = NSMenuItem(title: "Quit TextSnipper", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self

        menu.addItem(captureItem)
        menu.addItem(lineBreakItem)
        menu.addItem(shortcutItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func updateMenu() {
        let shortcut = SettingsStore.shortcut
        captureItem.title = "Capture Text"
        if let equivalent = KeyDisplay.menuKeyEquivalent(for: shortcut.keyCode) {
            captureItem.keyEquivalent = equivalent
            captureItem.keyEquivalentModifierMask = shortcut.modifierFlags
        } else {
            captureItem.keyEquivalent = ""
            captureItem.title = "Capture Text (\(KeyDisplay.shortcutString(shortcut)))"
        }
        lineBreakItem.state = SettingsStore.keepLineBreaks ? .on : .off
        statusItem.button?.toolTip = "TextSnipper — \(KeyDisplay.shortcutString(shortcut))"
    }

    @objc private func captureText() {
        CaptureSession.shared.begin()
    }

    @objc private func toggleLineBreaks() {
        SettingsStore.keepLineBreaks.toggle()
        updateMenu()
    }

    @objc private func changeShortcut() {
        hotkeys.unregister()
        shortcutPanel.onSubmit = { [weak self] shortcut in
            self?.applyShortcut(shortcut)
        }
        shortcutPanel.onCancel = { [weak self] in
            self?.restoreShortcut()
        }
        shortcutPanel.show()
    }

    @objc private func quit() {
        hotkeys.unregister()
        NSApp.terminate(nil)
    }

    private func applyShortcut(_ shortcut: Shortcut) {
        if hotkeys.register(shortcut) {
            SettingsStore.shortcut = shortcut
            updateMenu()
            return
        }
        restoreShortcut()
        showAlert(
            title: "Shortcut not available",
            message: "macOS or another app is already using that shortcut. Pick a different one."
        )
    }

    private func restoreShortcut() {
        if !hotkeys.register(SettingsStore.shortcut) {
            showAlert(
                title: "Shortcut not available",
                message: "The previous shortcut could not be restored. Choose a new one from the menu."
            )
        }
        updateMenu()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate()
        alert.runModal()
    }

    private func terminateIfAlreadyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !others.isEmpty else { return false }
        NSApp.terminate(nil)
        return true
    }
}
