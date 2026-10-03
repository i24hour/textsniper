import AppKit
import CoreGraphics
import ScreenCaptureKit
import TextSnipperCore

enum CaptureError: LocalizedError {
    case noDisplay
    case emptySelection

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "TextSnipper could not find the display for that selection."
        case .emptySelection:
            return "Drag a larger area around the text."
        }
    }
}

@MainActor
enum ScreenGrabber {
    static func capture(screenRect: CGRect) async throws -> CGImage {
        let rect = screenRect.standardized
        guard rect.width >= 2, rect.height >= 2 else {
            throw CaptureError.emptySelection
        }

        guard let screen = NSScreen.screens.first(where: {
            $0.frame.contains(CGPoint(x: rect.midX, y: rect.midY))
        }) ?? NSScreen.screens.first(where: { $0.frame.intersects(rect) }) else {
            throw CaptureError.noDisplay
        }
        guard let displayID = screen.displayID else {
            throw CaptureError.noDisplay
        }
        guard let source = CaptureGeometry.displaySourceRect(globalRect: rect, screenFrame: screen.frame) else {
            throw CaptureError.emptySelection
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = source
        config.showsCursor = false
        let scale = max(screen.backingScaleFactor, 1)
        config.width = max(1, Int((source.width * scale).rounded()))
        config.height = max(1, Int((source.height * scale).rounded()))
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = deviceDescription[key] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }
}
