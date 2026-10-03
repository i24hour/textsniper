import AppKit
import Foundation

struct Shortcut: Codable, Equatable {
    var keyCode: UInt16
    var command: Bool
    var shift: Bool
    var option: Bool
    var control: Bool

    /// Carbon virtual key code for the "2" key (kVK_ANSI_2).
    static let captureDefault = Shortcut(
        keyCode: 19,
        command: true,
        shift: true,
        option: false,
        control: false
    )

    var modifierFlags: NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if command { flags.insert(.command) }
        if shift { flags.insert(.shift) }
        if option { flags.insert(.option) }
        if control { flags.insert(.control) }
        return flags
    }
}

enum SettingsStore {
    private static let shortcutKey = "shortcut"
    private static let lineBreaksKey = "keepLineBreaks"

    static var keepLineBreaks: Bool {
        get {
            if UserDefaults.standard.object(forKey: lineBreaksKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: lineBreaksKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: lineBreaksKey)
        }
    }

    static var shortcut: Shortcut {
        get {
            guard let data = UserDefaults.standard.data(forKey: shortcutKey),
                  let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
                return .captureDefault
            }
            return shortcut
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: shortcutKey)
            }
        }
    }
}
