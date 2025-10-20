import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, ObservableObject {
    static let shared = AppDelegate()
    var compactQueryWindow: NSWindow?
    var settingsWindow: NSWindow?
    var pendingFiles: [FileAttachment] = []

    @objc func openCompactQueryWindow() {
        // Check if existing window is still valid
        if let existingWindow = compactQueryWindow, existingWindow.isVisible {
            bringWindowToForeground(existingWindow)
            return
        }
        // Create new window with empty context
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ContextKey Quick Window"

        // Use saved position if available, otherwise center
        if let savedPosition = DataManager.shared.quickWindowPosition {
            window.setFrameOrigin(savedPosition)
        } else {
            window.center()
        }

        window.delegate = self
        window.isReleasedWhenClosed = false // Keep window in memory

        updateCompactQueryView(window: window, context: "", files: [])

        compactQueryWindow = window
        bringWindowToForeground(window)
    }

    func openCompactQueryWindowWithText(_ text: String) {
        // Check if existing window is still valid
        if let existingWindow = compactQueryWindow, existingWindow.isVisible {
            updateCompactQueryView(window: existingWindow, context: text, files: [])
            bringWindowToForeground(existingWindow)
            return
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ContextKey Quick Window"

        // Use saved position if available, otherwise center
        if let savedPosition = DataManager.shared.quickWindowPosition {
            window.setFrameOrigin(savedPosition)
        } else {
            window.center()
        }

        window.delegate = self
        window.isReleasedWhenClosed = false

        updateCompactQueryView(window: window, context: text, files: [])

        compactQueryWindow = window
        bringWindowToForeground(window)
    }

    func openCompactQueryWindowWithFiles(context: String, files: [FileAttachment]) {
        pendingFiles = files

        // Check if existing window is still valid
        if let existingWindow = compactQueryWindow, existingWindow.isVisible {
            updateCompactQueryView(window: existingWindow, context: context, files: files)
            bringWindowToForeground(existingWindow)
            pendingFiles = []
            return
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ContextKey Quick Window"

        // Use saved position if available, otherwise center
        if let savedPosition = DataManager.shared.quickWindowPosition {
            window.setFrameOrigin(savedPosition)
        } else {
            window.center()
        }

        window.delegate = self
        window.isReleasedWhenClosed = false

        updateCompactQueryView(window: window, context: context, files: files)

        compactQueryWindow = window
        bringWindowToForeground(window)
        pendingFiles = []
    }

    private func updateCompactQueryView(window: NSWindow, context: String, files: [FileAttachment] = []) {
        let dataManager = DataManager.shared

        // Get the existing LLM manager from DataManager
        guard let llmManager = dataManager.llmManager else {
            print("Error: LLMManager not initialized")
            return
        }

        // Use config count as id to force view refresh when configs change
        let contentView = CompactQueryView(llmManager: llmManager, dataManager: dataManager, initialContext: context, attachedFiles: files)
            .id(llmManager.configurations.count)
        window.contentView = NSHostingView(rootView: contentView)
    }

    private func bringWindowToForeground(_ window: NSWindow) {
        window.collectionBehavior = [.moveToActiveSpace, .managed]

        // Force activate the app
        NSRunningApplication.current.activate()

        // Show window
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Force the window to be key and main
        window.makeKey()
        window.makeMain()

        // Post notification multiple times to ensure focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .focusTextField, object: nil)
            NSRunningApplication.current.activate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            NotificationCenter.default.post(name: .focusTextField, object: nil)
            NSRunningApplication.current.activate()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === compactQueryWindow {
            print("Compact query window closing")
            // Save the window position before closing
            DataManager.shared.saveQuickWindowPosition(window.frame.origin)
        }
    }

    func windowDidMove(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === compactQueryWindow {
            // Save position whenever user moves the window
            DataManager.shared.saveQuickWindowPosition(window.frame.origin)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Just hide the window instead of closing it completely
        sender.orderOut(nil)
        return false
    }

    func openSettingsWindow() {
        // Check if settings window already exists and is visible
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        // Create new settings window
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 600, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let dataManager = DataManager.shared
        guard let llmManager = dataManager.llmManager else {
            print("Error: LLMManager not initialized")
            return
        }

        let settingsView = SettingsView(
            llmManager: llmManager,
            hotkeyManager: HotkeyManager.shared,
            dataManager: dataManager
        )
        window.contentView = NSHostingView(rootView: settingsView)

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
    }
}

extension Notification.Name {
    static let focusTextField = Notification.Name("focusTextField")
}
