import SwiftUI

/// Notification to open settings from anywhere in the app
extension Notification.Name {
    static let closeRecordingWindow = Notification.Name("closeRecordingWindow")
    static let openVoiceScribeSettings = Notification.Name("openVoiceScribeSettings")
}

/// Invisible view that keeps SwiftUI's lifecycle alive for the Settings scene.
/// This window is positioned off-screen and made completely invisible.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .onReceive(NotificationCenter.default.publisher(for: .openVoiceScribeSettings)) { _ in
                openSettingsFront()
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
