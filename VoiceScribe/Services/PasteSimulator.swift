import Foundation
import AppKit
@preconcurrency import ApplicationServices
import os.log

private let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "PasteSimulator")

/// Manages simulating paste operations using CGEvent for smart paste functionality
@MainActor
final class PasteSimulator: PasteClient {

    // MARK: - Properties

    /// Singleton instance
    static let shared = PasteSimulator()

    private init() {}

    // MARK: - Permission Management

    /// Check if the app has accessibility permissions
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permissions from the user
    /// This will show the system dialog prompting the user to enable accessibility
    nonisolated func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Open System Settings to the Privacy & Security > Accessibility pane
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
            logger.info("Opened accessibility settings")
        }
    }

    // MARK: - Paste Simulation

    /// Simulate a Cmd+V paste operation
    /// - Returns: True if the paste was successfully simulated, false otherwise
    @discardableResult
    private func simulatePaste() async -> Bool {
        guard hasAccessibilityPermission else {
            logger.warning("Cannot simulate paste - no accessibility permission")
            return false
        }

        logger.info("Simulating Cmd+V paste")

        // Create Cmd+V key down event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x09, // V key
            keyDown: true
        ) else {
            logger.error("Failed to create key down event")
            return false
        }

        // Set Command modifier
        keyDownEvent.flags = .maskCommand

        // Create Cmd+V key up event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: 0x09, // V key
            keyDown: false
        ) else {
            logger.error("Failed to create key up event")
            return false
        }

        // Set Command modifier
        keyUpEvent.flags = .maskCommand

        // Post the events with a tiny async gap to mimic real keypress timing
        keyDownEvent.post(tap: .cghidEventTap)
        try? await Task.sleep(for: .milliseconds(50))
        keyUpEvent.post(tap: .cghidEventTap)

        logger.info("Paste simulation completed")
        return true
    }

    /// Simulate paste with automatic delay
    /// - Parameter delay: Delay in seconds before simulating paste (default: 0.2)
    func simulatePasteWithDelay(delay: TimeInterval = 0.2) async -> Bool {
        try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
        return await simulatePaste()
    }
}
