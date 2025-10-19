import Cocoa
import Carbon
import PDFKit

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyRef2: EventHotKeyRef?  // Second hotkey for quick window
    @Published var currentHotkey: UInt32 = UInt32(kVK_ANSI_J)
    @Published var currentModifiers: UInt32 = UInt32(cmdKey)
    @Published var quickWindowHotkey: UInt32 = UInt32(kVK_ANSI_K)  // Default: Cmd+K
    @Published var quickWindowModifiers: UInt32 = UInt32(cmdKey)

    private let userDefaultsKeyCode = "hotkeyKeyCode"
    private let userDefaultsModifiers = "hotkeyModifiers"
    private let userDefaultsQuickWindowKeyCode = "quickWindowHotkeyKeyCode"
    private let userDefaultsQuickWindowModifiers = "quickWindowHotkeyModifiers"

    private init() {
        loadHotkeysFromDefaults()
        registerHotkeys()
    }

    private func loadHotkeysFromDefaults() {
        if UserDefaults.standard.object(forKey: userDefaultsKeyCode) != nil {
            currentHotkey = UInt32(UserDefaults.standard.integer(forKey: userDefaultsKeyCode))
            currentModifiers = UInt32(UserDefaults.standard.integer(forKey: userDefaultsModifiers))
        }
        if UserDefaults.standard.object(forKey: userDefaultsQuickWindowKeyCode) != nil {
            quickWindowHotkey = UInt32(UserDefaults.standard.integer(forKey: userDefaultsQuickWindowKeyCode))
            quickWindowModifiers = UInt32(UserDefaults.standard.integer(forKey: userDefaultsQuickWindowModifiers))
        }
    }

    private func saveHotkeysToDefaults() {
        UserDefaults.standard.set(Int(currentHotkey), forKey: userDefaultsKeyCode)
        UserDefaults.standard.set(Int(currentModifiers), forKey: userDefaultsModifiers)
        UserDefaults.standard.set(Int(quickWindowHotkey), forKey: userDefaultsQuickWindowKeyCode)
        UserDefaults.standard.set(Int(quickWindowModifiers), forKey: userDefaultsQuickWindowModifiers)
    }

    func registerHotkeys() {
        // Unregister existing hotkey
        unregisterHotkeys()

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
            print("Failed to install event handler: \(err)")
            return
        }

        // Register the hotkey
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(("CTXK" as NSString).utf8String!.pointee) << 24 |
                             OSType(("CTXK" as NSString).utf8String!.advanced(by: 1).pointee) << 16 |
                             OSType(("CTXK" as NSString).utf8String!.advanced(by: 2).pointee) << 8 |
                             OSType(("CTXK" as NSString).utf8String!.advanced(by: 3).pointee)
        hotKeyID.id = 1

        let hotKeyErr = RegisterEventHotKey(
            currentHotkey,
            currentModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if hotKeyErr != noErr {
            print("Failed to register hotkey 1: \(hotKeyErr)")
        } else {
            print("Hotkey 1 registered successfully: keyCode=\(currentHotkey), modifiers=\(currentModifiers)")
        }

        // Register the second hotkey for quick window
        var hotKeyID2 = EventHotKeyID()
        hotKeyID2.signature = OSType(("CTXK" as NSString).utf8String!.pointee) << 24 |
                              OSType(("CTXK" as NSString).utf8String!.advanced(by: 1).pointee) << 16 |
                              OSType(("CTXK" as NSString).utf8String!.advanced(by: 2).pointee) << 8 |
                              OSType(("CTXK" as NSString).utf8String!.advanced(by: 3).pointee)
        hotKeyID2.id = 2  // Different ID for second hotkey

        let hotKeyErr2 = RegisterEventHotKey(
            quickWindowHotkey,
            quickWindowModifiers,
            hotKeyID2,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef2
        )

        if hotKeyErr2 != noErr {
            print("Failed to register hotkey 2: \(hotKeyErr2)")
        } else {
            print("Hotkey 2 registered successfully: keyCode=\(quickWindowHotkey), modifiers=\(quickWindowModifiers)")
        }
    }

    private func unregisterHotkeys() {
        // Unregister the first hotkey reference
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        // Unregister the second hotkey reference
        if let hotKeyRef2 = hotKeyRef2 {
            UnregisterEventHotKey(hotKeyRef2)
            self.hotKeyRef2 = nil
        }

        // Remove event handler
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
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
            if hotKeyID.id == 1 {
                print("Hotkey 1: Copy and open compact window")
                copyAndOpenCompactWindow()
                return noErr
            } else if hotKeyID.id == 2 {
                print("Hotkey 2: Open quick window without context")
                openQuickWindowOnly()
                return noErr
            }
        }

        return OSStatus(eventNotHandledErr)
    }

    private func openQuickWindowOnly() {
        print("🪟 Opening quick window without context")
        DispatchQueue.main.async {
            AppDelegate.shared.openCompactQueryWindow()
        }
    }

    private func copyAndOpenCompactWindow() {
        // Copy selected content on a background thread to avoid blocking
        DispatchQueue.global(qos: .userInitiated).async {
            // First, simulate Cmd+C to copy whatever is selected
            self.performCopy()

            // Wait for copy operation to complete
            Thread.sleep(forTimeInterval: 0.2)

            // Now check what we got - file URLs or text?
            if let filePaths = self.checkForFileURLsInPasteboard(), !filePaths.isEmpty {
                print("📁 Selected files detected: \(filePaths)")
                self.handleSelectedFiles(filePaths)
                return
            }

            // If no files, treat as text
            let pasteboard = NSPasteboard.general
            if let text = pasteboard.string(forType: .string), !text.isEmpty {
                print("📝 Copied text: \(text.prefix(100))")
                DispatchQueue.main.async {
                    AppDelegate.shared.openCompactQueryWindowWithText(text)
                }
            } else {
                print("⚠️ Nothing copied")
                DispatchQueue.main.async {
                    AppDelegate.shared.openCompactQueryWindow()
                }
            }
        }
    }

    private func performCopy() {
        print("📋 Performing Cmd+C to copy selection...")
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
    }

    private func checkForFileURLsInPasteboard() -> [String]? {
        print("🔍 Checking pasteboard for file URLs...")

        let pasteboard = NSPasteboard.general

        // Check if pasteboard contains file URLs
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            let filePaths = fileURLs.map { $0.path }
            if !filePaths.isEmpty {
                print("✅ Got \(filePaths.count) file(s) from pasteboard")
                for path in filePaths {
                    print("  📄 \(path)")
                }
                return filePaths
            }
        }

        print("⚠️ No file URLs found in pasteboard")
        return nil
    }

    private func handleSelectedFiles(_ filePaths: [String]) {
        var fileContents: [(path: String, name: String, content: String)] = []
        var fileAttachments: [FileAttachment] = []

        for filePath in filePaths {
            let fileURL = URL(fileURLWithPath: filePath)
            let fileName = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension.lowercased()

            print("📁 Processing file: \(fileName) (.\(fileExtension))")

            // Check if it's an image file
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic", "webp"]
            if imageExtensions.contains(fileExtension) {
                // Handle image files
                if let imageData = try? Data(contentsOf: fileURL) {
                    print("✅ Read image file: \(fileName), size: \(imageData.count) bytes")
                    let attachment = FileAttachment(name: fileName, path: filePath, imageData: imageData, isImage: true)
                    fileAttachments.append(attachment)
                    // Add placeholder to context for image
                    fileContents.append((path: filePath, name: fileName, content: "[Image: \(fileName)]"))
                } else {
                    print("❌ Failed to read image: \(fileName)")
                }
                continue
            }

            // Handle non-image files
            var content: String?

            // Handle PDFs
            if fileExtension == "pdf" {
                content = extractPDFText(from: fileURL)
                if content != nil {
                    print("✅ Extracted PDF text: \(fileName), size: \(content!.count) chars")
                }
            }
            // Handle text-based files
            else if ["txt", "swift", "py", "js", "ts", "json", "xml", "html", "css", "md", "yaml", "yml", "sh", "c", "cpp", "h", "java", "rb", "go", "rs"].contains(fileExtension) {
                content = try? String(contentsOf: fileURL, encoding: .utf8)
                if content != nil {
                    print("✅ Read text file: \(fileName), size: \(content!.count) chars")
                }
            }
            // Try UTF-8 for unknown text files
            else {
                content = try? String(contentsOf: fileURL, encoding: .utf8)
                if content != nil {
                    print("✅ Read file as UTF-8: \(fileName), size: \(content!.count) chars")
                } else {
                    print("⚠️ Could not read file: \(fileName) - might be binary")
                }
            }

            if let content = content, !content.isEmpty {
                fileContents.append((path: filePath, name: fileName, content: content))
                let attachment = FileAttachment(name: fileName, path: filePath)
                fileAttachments.append(attachment)
            } else {
                print("❌ Failed to extract content from: \(fileName)")
                // Add file with error message
                fileContents.append((path: filePath, name: fileName, content: "[Could not read file content - file may be binary or corrupted]"))
                let attachment = FileAttachment(name: fileName, path: filePath)
                fileAttachments.append(attachment)
            }
        }

        if !fileAttachments.isEmpty {
            print("📄 Processed \(fileAttachments.count) file(s)")

            DispatchQueue.main.async {
                // Pass empty string as context - we'll load files on-demand
                AppDelegate.shared.openCompactQueryWindowWithFiles(context: "", files: fileAttachments)
            }
        } else {
            print("⚠️ No files were successfully processed!")
        }
    }

    func updateHotkey(_ newHotkey: UInt32, modifiers: UInt32) {
        print("Updating hotkey 1 to: keyCode=\(newHotkey), modifiers=\(modifiers)")
        currentHotkey = newHotkey
        currentModifiers = modifiers
        saveHotkeysToDefaults()
        registerHotkeys()
    }

    func updateQuickWindowHotkey(_ newHotkey: UInt32, modifiers: UInt32) {
        print("Updating hotkey 2 to: keyCode=\(newHotkey), modifiers=\(modifiers)")
        quickWindowHotkey = newHotkey
        quickWindowModifiers = modifiers
        saveHotkeysToDefaults()
        registerHotkeys()
    }

    private func extractPDFText(from url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else {
            print("❌ Could not open PDF document")
            return nil
        }

        var extractedText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            if let pageText = page.string {
                extractedText += pageText + "\n\n"
            }
        }

        return extractedText.isEmpty ? nil : extractedText
    }

    deinit {
        unregisterHotkeys()
    }
}

extension Notification.Name {
    static let openCompactWindow = Notification.Name("openCompactWindow")
    static let triggerCompactWindow = Notification.Name("triggerCompactWindow")
    static let openCompactWindowWithFiles = Notification.Name("openCompactWindowWithFiles")
}
