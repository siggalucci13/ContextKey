import SwiftUI

@main
struct ContextKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var hotkeyManager = HotkeyManager.shared
    @StateObject private var llmManager: LLMManager

    init() {
        let dataManager = DataManager.shared
        _llmManager = StateObject(wrappedValue: LLMManager(dataManager: dataManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(llmManager: llmManager, dataManager: dataManager, hotkeyManager: hotkeyManager)
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
