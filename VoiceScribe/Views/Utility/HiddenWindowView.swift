import SwiftUI

/// Notification to open settings from anywhere in the app
extension Notification.Name {
    static let openVoiceScribeSettings = Notification.Name("openVoiceScribeSettings")
}

/// Invisible view that keeps SwiftUI's lifecycle alive for the Settings scene.
/// This window is positioned off-screen and made completely invisible.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openVoiceScribeSettings)) { _ in
                openSettingsFront()
            }
            .onAppear {
                // Find and hide the lifecycle window
                DispatchQueue.main.async {
                    for window in NSApp.windows {
                        // Match by title or by being a tiny window
                        if window.title == "VoiceScribeLifecycle" ||
                           (window.frame.width <= 20 && window.frame.height <= 20) {
                            // Make the keepalive window truly invisible and non-interactive
                            window.styleMask = [.borderless]
                            window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                            window.isExcludedFromWindowsMenu = true
                            window.level = .floating
                            window.isOpaque = false
                            window.alphaValue = 0
                            window.backgroundColor = .clear
                            window.hasShadow = false
                            window.ignoresMouseEvents = true
                            window.canHide = false
                            window.setContentSize(NSSize(width: 1, height: 1))
                            window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                            break
                        }
                    }
                }
            }
    }

    private func openSettingsFront() {
        // Dismiss the key window if it's a floating window (like the recording bar)
        if let keyWindow = NSApp.keyWindow, keyWindow.level != .normal {
            keyWindow.orderOut(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }
}
