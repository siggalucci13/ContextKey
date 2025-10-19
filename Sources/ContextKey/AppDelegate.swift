import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    static let shared = AppDelegate()
    var compactQueryWindow: NSWindow?
    
    @objc func openCompactQueryWindow() {
        let copiedText = NSPasteboard.general.string(forType: .string) ?? ""
        
        if let existingWindow = compactQueryWindow {
            updateCompactQueryView(window: existingWindow, context: copiedText)
            bringWindowToForeground(existingWindow)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ContextKey Quick Window"
        window.center()
        
        updateCompactQueryView(window: window, context: copiedText)
        
        compactQueryWindow = window
        bringWindowToForeground(window)
    }
    
    private func updateCompactQueryView(window: NSWindow, context: String) {
        let mqttManager = MQTTManager.shared
        let llmManager = LLMManager(mqttManager: mqttManager)
        
        let contentView = CompactQueryView(llmManager: llmManager, mqttManager: mqttManager, initialContext: context)
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func bringWindowToForeground(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.collectionBehavior = [.moveToActiveSpace, .managed]
    }
}
