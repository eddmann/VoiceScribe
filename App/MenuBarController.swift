import AppKit
import SwiftUI

/// Custom NSWindow subclass that allows borderless windows to become key
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }
}

/// Manages the menu bar status item and window lifecycle
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var recordingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private let appState: AppState
    private var eventMonitor: Any?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        setupMenuBar()
    }

    private func setupMenuBar() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        // Set icon
        if let image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoiceScribe") {
            image.isTemplate = true
            button.image = image
        }

        // Set action
        button.action = #selector(statusItemClicked)
        button.target = self

        // Create menu
        let menu = NSMenu()

        // Record item
        let recordItem = NSMenuItem(
            title: "Record",
            action: #selector(showRecordingWindow),
            keyEquivalent: ""
        )
        recordItem.target = self
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit VoiceScribe",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func statusItemClicked() {
        showRecordingWindow()
    }

    @objc func showRecordingWindow() {
        if let window = recordingWindow, window.isVisible {
            window.orderOut(nil)
            return
        }

        // Capture the current frontmost app before showing VoiceScribe
        // This enables smart paste functionality
        AppFocusManager.shared.capturePreviousApplication()

        // Create or show recording window
        if recordingWindow == nil {
            recordingWindow = createRecordingWindow()
        }

        guard let window = recordingWindow else { return }

        // Center and show window
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Activate app and make sure window can receive keyboard input
        NSApp.activate(ignoringOtherApps: true)

        // Force window to accept first responder status for keyboard events
        window.makeFirstResponder(window.contentView)
    }

    private func createRecordingWindow() -> NSWindow {
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Allow window to become key to receive keyboard events
        window.isMovableByWindowBackground = true

        // Set content view
        let contentView = RecordingView()
            .environment(appState)

        window.contentView = NSHostingView(rootView: contentView)

        // Handle window closing
        window.setFrameAutosaveName("RecordingWindow")

        // Add keyboard handling
        setupWindowKeyHandling(window)

        return window
    }

    private func setupWindowKeyHandling(_ window: NSWindow) {
        // Clean up existing monitor if any
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Add local event monitor for ESC key
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak window] event in
            guard let window = window, window.isKeyWindow else { return event }

            // ESC key closes window and cancels recording
            if event.keyCode == 53 { // ESC
                Task { @MainActor in
                    if self?.appState.recordingState.isRecording == true {
                        await self?.appState.cancelRecording()
                    }
                    window.orderOut(nil)
                }
                return nil // Consume the ESC event
            }

            // Let all other keys pass through to SwiftUI (including Space)
            return event
        }
    }

    deinit {
        // Clean up event monitor
        MainActor.assumeIsolated {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }

    @objc func showSettings() {
        // If settings window already exists and is visible, just bring it to front
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create settings window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.isReleasedWhenClosed = false

        // Create settings view
        let settingsView = SettingsView(appState: appState)

        window.contentView = NSHostingView(rootView: settingsView)
        window.center()

        // Set delegate to handle window close
        window.delegate = self

        // Store reference
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    func hideRecordingWindow() {
        recordingWindow?.orderOut(nil)
    }
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        Task { @MainActor in
            // Clean up settings window reference when it closes
            if window === self.settingsWindow {
                self.settingsWindow = nil
            }
        }
    }
}
