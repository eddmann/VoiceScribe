import AppKit
import SwiftUI
import SwiftData

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
    private var historyWindow: NSWindow?
    private let appState: AppState
    private let modelContainer: ModelContainer?
    private var eventMonitor: Any?
    private var standardMenu: NSMenu?
    private var extendedMenu: NSMenu?

    init(appState: AppState, modelContainer: ModelContainer? = nil) {
        self.appState = appState
        self.modelContainer = modelContainer
        super.init()
        setupMenuBar()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeRecordingWindow),
            name: .closeRecordingWindow,
            object: nil
        )
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

        // Handle both left and right clicks manually (no default menu)
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        // Create both menus
        standardMenu = createStandardMenu()
        extendedMenu = createContextMenu()
    }

    private func createStandardMenu() -> NSMenu {
        let menu = NSMenu()

        // Record item
        let recordItem = NSMenuItem(
            title: "Record",
            action: #selector(showRecordingWindow),
            keyEquivalent: ""
        )
        recordItem.target = self
        recordItem.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Record")
        menu.addItem(recordItem)

        menu.addItem(NSMenuItem.separator())

        // History item
        let historyItem = NSMenuItem(
            title: "History",
            action: #selector(showHistory),
            keyEquivalent: ""
        )
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "History")
        menu.addItem(historyItem)

        // Settings item
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(showSettings),
            keyEquivalent: ""
        )
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        menu.addItem(settingsItem)

        return menu
    }

    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()

        // Settings item
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit item with ⌘Q shortcut
        let quitItem = NSMenuItem(title: "Quit VoiceScribe", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        // Choose menu based on click type
        let menuToShow = (event.type == .rightMouseUp) ? extendedMenu : standardMenu

        // Assign menu, show it, then clear reference
        statusItem?.menu = menuToShow
        statusItem?.button?.performClick(nil)

        // Clear menu reference so button action works next time
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    @objc func showRecordingWindow() {
        if let window = recordingWindow, window.isVisible {
            Task { @MainActor in
                await appState.cancelActiveWork()
            }
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

        // Position at bottom center of screen
        positionWindowAtBottomCenter(window)
        window.makeKeyAndOrderFront(nil)

        // Activate app and make sure window can receive keyboard input
        NSApp.activate(ignoringOtherApps: true)

        // Force window to accept first responder status for keyboard events
        window.makeFirstResponder(window.contentView)
    }

    private func positionWindowAtBottomCenter(_ window: NSWindow) {
        guard let screen = NSScreen.main else {
            window.center()
            return
        }

        let screenFrame = screen.visibleFrame
        let shadowPadding: CGFloat = 24
        let windowWidth: CGFloat = 360 + shadowPadding * 2
        let windowHeight: CGFloat = 52 + shadowPadding * 2
        let bottomPadding: CGFloat = 60 - shadowPadding  // Adjust for shadow space

        let x = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        let y = screenFrame.origin.y + bottomPadding

        window.setFrame(
            NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            display: true
        )
    }

    @objc private func closeRecordingWindow() {
        Task { @MainActor in
            await appState.cancelActiveWork()
        }
        recordingWindow?.orderOut(nil)
    }

    private func createRecordingWindow() -> NSWindow {
        // Window is larger than content to accommodate shadow (radius: 10, y-offset: 4)
        let shadowPadding: CGFloat = 24
        let windowWidth: CGFloat = 360 + shadowPadding * 2
        let windowHeight: CGFloat = 52 + shadowPadding * 2

        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Allow window to become key to receive keyboard events
        window.isMovableByWindowBackground = true

        // Set content view with new floating bar - centered in larger window for shadow space
        let contentView = FloatingRecordBar()
            .environment(appState)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        window.contentView = NSHostingView(rootView: contentView)

        // Handle window closing
        window.setFrameAutosaveName("RecordingWindow")
        window.delegate = self

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
                    await self?.appState.cancelActiveWork()
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
        // Use native SwiftUI Settings scene via notification to HiddenWindowView
        NotificationCenter.default.post(name: .openVoiceScribeSettings, object: nil)
    }

    @objc func showHistory() {
        // Dismiss the key window if it's a floating window (like the recording bar)
        if let keyWindow = NSApp.keyWindow, keyWindow.level != .normal {
            keyWindow.orderOut(nil)
        }

        // If history window already exists and is visible, just bring it to front
        if let window = historyWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Create history window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Transcription History"
        window.isReleasedWhenClosed = false

        // Create history view - use shared model container to prevent observation errors
        if let container = modelContainer {
            window.contentView = NSHostingView(rootView: HistoryView().modelContainer(container))
        } else {
            // Fallback: create new container (shouldn't happen in normal operation)
            window.contentView = NSHostingView(rootView: HistoryView().modelContainer(for: TranscriptionRecord.self))
        }
        window.center()

        // Set delegate to handle window close
        window.delegate = self

        // Store reference
        historyWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        appState.cleanup()
        NSApplication.shared.terminate(nil)
    }

    func hideRecordingWindow() {
        Task { @MainActor in
            await appState.cancelActiveWork()
        }
        recordingWindow?.orderOut(nil)
    }

    #if DEBUG
    /// Shows recording window for demo mode without capturing previous app.
    /// Used for App Store screenshots.
    func showRecordingWindowForDemo() {
        // Create recording window if needed (skip previous app capture)
        if recordingWindow == nil {
            recordingWindow = createRecordingWindow()
        }

        guard let window = recordingWindow else { return }

        // Position at bottom center of screen
        positionWindowAtBottomCenter(window)
        window.makeKeyAndOrderFront(nil)

        // Activate app
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(window.contentView)
    }
    #endif
}

// MARK: - NSWindowDelegate
extension MenuBarController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        Task { @MainActor in
            // Clean up window references when they close
            if window === self.historyWindow {
                self.historyWindow = nil
            }
            if window === self.recordingWindow {
                await self.appState.cancelActiveWork()
                self.recordingWindow = nil
            }
        }
    }
}
