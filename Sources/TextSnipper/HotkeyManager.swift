import Carbon
import Foundation

final class HotkeyManager {
    var onPressed: @MainActor () -> Void = {}

    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var handlerInstalled = false

    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        installHandlerIfNeeded()

        var hotKey: EventHotKeyRef?
        let id = EventHotKeyID(signature: fourCC("TSNP"), id: 1)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            carbonModifiers(shortcut),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard status == noErr, let hotKey else { return false }
        self.hotKey = hotKey
        return true
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &spec,
            userData,
            &handler
        )
        handlerInstalled = (status == noErr)
    }

    private func carbonModifiers(_ shortcut: Shortcut) -> UInt32 {
        var flags: UInt32 = 0
        if shortcut.command { flags |= UInt32(cmdKey) }
        if shortcut.shift { flags |= UInt32(shiftKey) }
        if shortcut.option { flags |= UInt32(optionKey) }
        if shortcut.control { flags |= UInt32(controlKey) }
        return flags
    }

    private func fourCC(_ string: String) -> OSType {
        var result: OSType = 0
        for scalar in string.unicodeScalars.prefix(4) {
            result = (result << 8) | OSType(scalar.value)
        }
        return result
    }
}

private func carbonHotKeyHandler(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            manager.onPressed()
        }
    }
    return noErr
}
