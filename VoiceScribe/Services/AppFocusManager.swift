import Foundation
import AppKit
import os.log

private let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "AppFocusManager")

/// Manages tracking and restoring application focus for smart paste functionality
@MainActor
final class AppFocusManager: AppFocusClient {

    // MARK: - Properties

    /// The application that was active before VoiceScribe
    private var previousApplication: NSRunningApplication?

    /// Singleton instance
    static let shared = AppFocusManager()

    private init() {}

    // MARK: - Public Methods

    /// Capture the currently frontmost application (excluding VoiceScribe)
    func capturePreviousApplication() {
        let frontmost = NSWorkspace.shared.frontmostApplication

        // Don't capture if VoiceScribe is the frontmost app
        guard let app = frontmost,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            logger.info("VoiceScribe is frontmost, not capturing previous app")
            return
        }

        previousApplication = app

        if let appName = app.localizedName {
            logger.info("Captured previous app: \(appName)")
        }
    }

    /// Restore focus to the previously captured application
    /// - Returns: True if focus was successfully restored, false otherwise
    @discardableResult
    func restorePreviousApplication() -> Bool {
        guard let app = previousApplication else {
            logger.warning("No previous application to restore")
            return false
        }

        // Check if the app is still running
        guard app.isActive || NSWorkspace.shared.runningApplications.contains(app) else {
            logger.warning("Previous app is no longer running")
            previousApplication = nil
            return false
        }

        // Activate the application
        let success = app.activate()

        if success {
            if let appName = app.localizedName {
                logger.info("Successfully restored focus to: \(appName)")
            }
        } else {
            logger.error("Failed to restore focus to previous app")
        }

        return success
    }

    /// Get the name of the previously captured application
    var previousApplicationName: String? {
        previousApplication?.localizedName
    }

    /// Clear the stored previous application
    func clearPreviousApplication() {
        previousApplication = nil
        logger.debug("Cleared previous application reference")
    }

    /// Check if we have a valid previous application to restore to
    var hasPreviousApplication: Bool {
        guard let app = previousApplication else { return false }
        return app.isActive || NSWorkspace.shared.runningApplications.contains(app)
    }
}
