import AppKit
import Carbon.HIToolbox

/// Raccourci clavier global (API Carbon : pas besoin d'autorisation Accessibilité).
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // modificateurs Carbon
    var label: String

    static let `default` = Shortcut(keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey), label: "⌥ Espace")

    static func from(event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        var label = ""
        if flags.contains(.control) { mods |= UInt32(controlKey); label += "⌃" }
        if flags.contains(.option) { mods |= UInt32(optionKey); label += "⌥" }
        if flags.contains(.shift) { mods |= UInt32(shiftKey); label += "⇧" }
        if flags.contains(.command) { mods |= UInt32(cmdKey); label += "⌘" }
        guard mods != 0 else { return nil } // au moins un modificateur
        label += " " + keyName(event)
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: mods, label: label)
    }

    private static func keyName(_ e: NSEvent) -> String {
        switch Int(e.keyCode) {
        case kVK_Space: return "Espace"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        default:
            let fKeys = [kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
                         kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20]
            if let i = fKeys.firstIndex(of: Int(e.keyCode)) { return "F\(i + 1)" }
            return (e.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }

    static func load() -> Shortcut {
        guard let d = UserDefaults.standard.data(forKey: "shortcut"),
              let s = try? JSONDecoder().decode(Shortcut.self, from: d) else { return .default }
        return s
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: "shortcut")
    }
}

final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, info in
            guard let info else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(info).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    @discardableResult
    func register(_ s: Shortcut) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x4D414C21), id: 1)
        return RegisterEventHotKey(s.keyCode, s.modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }
}
