import AppKit
import Carbon
import Observation
import ShelferryCore
import ShelferryProtocol

/// Registers individual system hotkeys; it never monitors arbitrary keyboard input.
@MainActor @Observable
final class GlobalHotkeys {
    private(set) var error: String?
    @ObservationIgnored var onAction: (GlobalShelfAction) -> Void = { _ in }
    @ObservationIgnored private var registrations: [KeyCombo: Registration] = [:]
    @ObservationIgnored private var eventHandler: EventHandlerRef?
    @ObservationIgnored private var paused = false
    @ObservationIgnored private var nextID: UInt32 = 1
    private struct Registration { var reference: EventHotKeyRef; var id: UInt32; var action: GlobalShelfAction }

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr else { return status }
            MainActor.assumeIsolated {
                let controller = Unmanaged<GlobalHotkeys>.fromOpaque(context).takeUnretainedValue()
                if let entry = controller.registrations.values.first(where: { $0.id == identifier.id }) {
                    controller.onAction(entry.action)
                }
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
    }

    func apply(_ shortcuts: [String: String]) {
        guard !paused else { return }
        var staged: [KeyCombo: Registration] = [:]
        do {
            for (key, text) in shortcuts {
                guard let action = GlobalShelfAction(rawValue: key), let combo = KeyCombo(text) else { continue }
                if var existing = registrations[combo] {
                    existing.action = action; staged[combo] = existing; continue
                }
                var reference: EventHotKeyRef?
                let id = nextID; nextID += 1
                let status = RegisterEventHotKey(UInt32(combo.keyCode), combo.modifiers.carbonFlags,
                    EventHotKeyID(signature: 0x53484652, id: id), GetApplicationEventTarget(), 0, &reference)
                guard status == noErr, let reference else {
                    throw ServiceError("Could not register \(combo.symbols.joined()). Another app may use it. Choose another shortcut.")
                }
                staged[combo] = Registration(reference: reference, id: id, action: action)
            }
            for (combo, entry) in registrations where staged[combo] == nil { UnregisterEventHotKey(entry.reference) }
            registrations = staged; error = nil
        } catch {
            for (combo, entry) in staged where registrations[combo] == nil { UnregisterEventHotKey(entry.reference) }
            self.error = error.localizedDescription
        }
    }

    func resume(_ shortcuts: [String: String]) {
        paused = false
        apply(shortcuts)
    }

    func suspend() {
        paused = true
        registrations.values.forEach { UnregisterEventHotKey($0.reference) }
        registrations.removeAll()
    }
}

extension KeyCombo.Modifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.command) { insert(.command) }
    }
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.control) { flags |= UInt32(controlKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.command) { flags |= UInt32(cmdKey) }
        return flags
    }
}
