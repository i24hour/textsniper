import AppKit
import CoreGraphics
import TextSnipperCore
import os

@MainActor
final class CaptureSession {
    static let shared = CaptureSession()

    private var windows: [SelectionWindow] = []
    private var escapeMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var selecting = false
    private var cursorPushed = false
    private var generation = 0
    private let logger = Logger(subsystem: "local.priyanshu.TextSnipper", category: "capture")

    private init() {}

    func begin() {
        guard ScreenRecordingPermission.ensureAccess() else { return }
        if selecting {
            teardownUI()
        }
        guard !NSScreen.screens.isEmpty else {
            report(CaptureError.noDisplay)
            return
        }

        generation += 1
        selecting = true
        rememberFrontApp()
        NSApp.activate()
        showOverlays()
    }

    func cancel() {
        guard selecting else { return }
        teardownUI()
        restoreFrontApp()
    }

    private func showOverlays() {
        let mouse = NSEvent.mouseLocation
        var keyWindow: SelectionWindow?

        windows = NSScreen.screens.map { screen in
            let window = SelectionWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.isMovable = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.sharingType = .none
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false

            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onComplete = { [weak self, weak view, weak window] rect in
                guard let self, let view, let window else { return }
                self.finishSelection(rect, in: view, window: window)
            }
            view.onCancel = { [weak self] in
                self?.cancel()
            }
            window.contentView = view
            if screen.frame.contains(mouse) {
                keyWindow = window
            }
            return window
        }

        NSCursor.crosshair.push()
        cursorPushed = true

        let front = keyWindow ?? windows.first
        front?.makeKeyAndOrderFront(nil)
        for window in windows where window !== front {
            window.orderFrontRegardless()
        }
        if let front, let view = front.contentView {
            front.makeFirstResponder(view)
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            Task { @MainActor in
                self?.cancel()
            }
            return nil
        }
    }

    private func finishSelection(_ rect: CGRect, in view: NSView, window: NSWindow) {
        let screenRect = window.convertToScreen(view.convert(rect, to: nil))
        let token = generation
        let keepLineBreaks = SettingsStore.keepLineBreaks
        teardownUI()

        Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
                let image = try await ScreenGrabber.capture(screenRect: screenRect)
                let text = try await Task.detached(priority: .userInitiated) {
                    try OCRService.recognize(image, keepLineBreaks: keepLineBreaks)
                }.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard token == self.generation else { return }
                self.deliver(text, near: screenRect)
            } catch {
                self.logger.error("Capture failed: \(error.localizedDescription, privacy: .public)")
                guard token == self.generation else { return }
                self.report(error)
            }
        }
    }

    private func deliver(_ text: String, near screenRect: CGRect) {
        if text.isEmpty {
            HUD.shared.show("No text found", near: screenRect)
        } else {
            Clipboard.copy(text)
            HUD.shared.show("Copied", near: screenRect)
            NSSound(named: "Tink")?.play()
        }
        restoreFrontApp()
    }

    private func teardownUI() {
        selecting = false
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        if cursorPushed {
            NSCursor.pop()
            cursorPushed = false
        }
    }

    private func rememberFrontApp() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != NSRunningApplication.current.processIdentifier {
            previousApp = front
        }
    }

    private func restoreFrontApp() {
        guard let previous = previousApp else { return }
        previousApp = nil
        if previous.processIdentifier != NSRunningApplication.current.processIdentifier {
            previous.activate(from: .current, options: [])
        }
    }

    private func report(_ error: Error) {
        restoreFrontApp()
        let alert = NSAlert()
        alert.messageText = "Could not capture text"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Screen Recording Settings")
        NSApp.activate()
        if alert.runModal() == .alertSecondButtonReturn {
            ScreenRecordingPermission.openSettings()
        }
    }
}

private enum Clipboard {
    static func copy(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

enum ScreenRecordingPermission {
    private static let promptedKey = "didPromptForScreenRecording"

    static func ensureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        let promptedBefore = UserDefaults.standard.bool(forKey: promptedKey)
        UserDefaults.standard.set(true, forKey: promptedKey)
        if CGRequestScreenCaptureAccess() {
            return true
        }
        if promptedBefore {
            let alert = NSAlert()
            alert.messageText = "Allow screen recording"
            alert.informativeText = "TextSnipper needs Screen Recording permission to read the area you select. Turn it on for TextSnipper, then press the shortcut again."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Not Now")
            NSApp.activate()
            if alert.runModal() == .alertFirstButtonReturn {
                openSettings()
            }
        }
        return false
    }

    static func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for raw in candidates {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

private final class SelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionOverlayView: NSView {
    var onComplete: (CGRect) -> Void = { _ in }
    var onCancel: () -> Void = {}

    private var anchor: CGPoint?
    private var selection: CGRect = .zero

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds)
        if selection.width > 1, selection.height > 1 {
            path.append(NSBezierPath(rect: selection))
        }
        path.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.35).setFill()
        path.fill()

        guard selection.width > 1, selection.height > 1 else { return }
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: selection.insetBy(dx: 1, dy: 1))
        border.lineWidth = 2
        border.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        anchor = convert(event.locationInWindow, from: nil)
        selection = .zero
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        updateSelection(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        updateSelection(with: event)
        if selection.width >= 8, selection.height >= 8 {
            onComplete(selection)
        } else {
            onCancel()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel()
        }
    }

    private func updateSelection(with event: NSEvent) {
        guard let anchor else { return }
        let point = convert(event.locationInWindow, from: nil)
        var rect = CGRect(
            x: min(anchor.x, point.x),
            y: min(anchor.y, point.y),
            width: abs(anchor.x - point.x),
            height: abs(anchor.y - point.y)
        )
        rect = rect.intersection(bounds)
        selection = rect.isNull ? .zero : rect
        needsDisplay = true
    }
}
