import SwiftUI

@main
struct ContextKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var mqttManager = MQTTManager.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var llmManager: LLMManager
    
    init() {
        let mqttManager = MQTTManager.shared
        _llmManager = StateObject(wrappedValue: LLMManager(mqttManager: mqttManager))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(llmManager: llmManager, mqttManager: mqttManager, hotkeyManager: hotkeyManager)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Open Compact Query Window") {
                    AppDelegate.shared.openCompactQueryWindow()
                }
                .keyboardShortcut("j", modifiers: [.command])
            }
        }
    }
}
