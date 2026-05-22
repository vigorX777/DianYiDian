import Carbon
import Foundation

@MainActor
final class GlobalShortcutService {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private let onSelectIndex: (Int) -> Void
    private(set) var registrationError: String?

    init(onSelectIndex: @escaping (Int) -> Void) {
        self.onSelectIndex = onSelectIndex
    }

    func registerDefaultShortcuts() {
        unregister()
        registrationError = nil

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData else {
                    return noErr
                }
                let service = Unmanaged<GlobalShortcutService>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else {
                    return status
                }
                Task { @MainActor in
                    service.onSelectIndex(Int(hotKeyID.id) - 1)
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard installStatus == noErr else {
            registrationError = "全局快捷键监听注册失败：\(installStatus)"
            return
        }

        for (index, keyCode) in keyCodes.enumerated() {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: fourCharCode("DYDY"), id: UInt32(index + 1))
            let status = RegisterEventHotKey(
                UInt32(keyCode),
                UInt32(optionKey | cmdKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
            } else if registrationError == nil {
                registrationError = "全局快捷键 ⌥⌘\(index + 1) 注册失败：\(status)"
            }
        }
    }

    func invalidate() {
        unregister()
    }

    private func unregister() {
        for ref in hotKeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private var keyCodes: [Int] {
        [
            kVK_ANSI_1,
            kVK_ANSI_2,
            kVK_ANSI_3,
            kVK_ANSI_4,
            kVK_ANSI_5,
            kVK_ANSI_6,
            kVK_ANSI_7,
            kVK_ANSI_8,
            kVK_ANSI_9
        ]
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        string.utf8.reduce(0) { result, character in
            (result << 8) + FourCharCode(character)
        }
    }
}
