import Foundation
import AppKit
import KeyboardShortcuts

/// Manages global keyboard shortcuts
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var onTrigger: (() -> Void)?

    private init() {}

    /// Start listening for the hotkey
    func startListening(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger

        KeyboardShortcuts.onKeyUp(for: .toggleRecording) { [weak self] in
            self?.onTrigger?()
        }
    }

    /// Stop listening for the hotkey
    func stopListening() {
        onTrigger = nil
    }
}

// MARK: - Keyboard Shortcut Extension
extension KeyboardShortcuts.Name {
    // Changed from ⌘⇧Space to ⌥⇧Space to avoid conflict with 1Password
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: [.option, .shift]))
}
