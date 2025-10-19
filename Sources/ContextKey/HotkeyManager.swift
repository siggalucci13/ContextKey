import Cocoa
import Carbon


class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    private var eventHandler: EventHandlerRef?
    @Published var currentHotkey: UInt32 = UInt32(kVK_ANSI_G)
    @Published var currentModifiers: UInt32 = UInt32(cmdKey)
    
    private var compactWindowHotkey: UInt32 = UInt32(kVK_ANSI_J)
    private var compactWindowModifiers: UInt32 = UInt32(cmdKey)

    private init() {
        registerHotkeys()
    }

    func registerHotkeys() {
        // Unregister existing hotkey if any
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }

        let hotkeys = [
            (currentHotkey, currentModifiers, 1),
            (compactWindowHotkey, compactWindowModifiers, 2)
        ]

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        let err = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, eventRef, userData) -> OSStatus in
                guard let eventRef = eventRef else { return OSStatus(eventNotHandledErr) }
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let hotKeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return hotKeyManager.handleHotKeyEvent(eventRef)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )

        if err != noErr {
            print("Failed to install event handler")
            return
        }

        for (hotkey, modifiers, id) in hotkeys {
            var hotKeyID = EventHotKeyID()
            hotKeyID.signature = OSType(("MYHT" as NSString).utf8String!.pointee) << 24 |
                                 OSType(("MYHT" as NSString).utf8String!.advanced(by: 1).pointee) << 16 |
                                 OSType(("MYHT" as NSString).utf8String!.advanced(by: 2).pointee) << 8 |
                                 OSType(("MYHT" as NSString).utf8String!.advanced(by: 3).pointee)
            hotKeyID.id = UInt32(id)

            let hotKeyErr = RegisterEventHotKey(
                hotkey,
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &eventHandler
            )

            if hotKeyErr != noErr {
                print("Failed to register hotkey \(id)")
            } else {
                print("Hotkey \(id) registered successfully")
            }
        }
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let err = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamName(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        if err == noErr {
            DispatchQueue.main.async {
                switch hotKeyID.id {
                case 1:
                    print("Main hotkey pressed")
                    self.copyAndSendText()
                case 2:
                    print("Compact window hotkey pressed")
                    self.copyAndOpenCompactWindow()
                default:
                    break
                }
            }
        }

        return OSStatus(eventNotHandledErr)
    }

    private func copyAndSendText() {
        if let text = copySelectedText() {
            print("Copied text: \(text)")
            MQTTManager.shared.sendTextToRaspberryPi(text: text)
        }
    }

    private func copyAndOpenCompactWindow() {
           if let text = copySelectedText() {
               print("Opening compact window with text: \(text)")
               DispatchQueue.main.async {
                   NSPasteboard.general.clearContents()
                   NSPasteboard.general.setString(text, forType: .string)
                   AppDelegate.shared.openCompactQueryWindow()
               }
           }
       }

    private func copySelectedText() -> String? {
        let source = CGEventSource(stateID: .hidSystemState)

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let cKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let cKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        cKeyDown?.flags = .maskCommand
        cKeyUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        cKeyDown?.post(tap: .cghidEventTap)
        cKeyUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)

        // Wait a bit for the copy operation to complete
        Thread.sleep(forTimeInterval: 0.1)

        // Now get the text from the pasteboard
        let pasteboard = NSPasteboard.general
        return pasteboard.string(forType: .string)
    }

    func updateHotkey(_ newHotkey: UInt32, modifiers: UInt32) {
        currentHotkey = newHotkey
        currentModifiers = modifiers
        registerHotkeys()
    }
}

extension Notification.Name {
    static let openCompactWindow = Notification.Name("openCompactWindow")
    static let triggerCompactWindow = Notification.Name("triggerCompactWindow")
}
