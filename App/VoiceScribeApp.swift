import SwiftUI
import SwiftData

/// VoiceScribe - Modern macOS transcription app
@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app - Settings scene doesn't create a default window
        Settings {
            EmptyView()
        }
    }
}

/// App delegate to manage menu bar and global state
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    var menuBarController: MenuBarController?
    let hotkeyManager = HotkeyManager.shared

    // Create model container
    private lazy var modelContainer: ModelContainer = {
        let schema = Schema([TranscriptionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            appState.modelContext = container.mainContext
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize model container (triggers lazy initialization)
        _ = modelContainer

        // Menu bar app - hide from Dock (even in debug mode)
        NSApplication.shared.setActivationPolicy(.accessory)

        // Setup menu bar with shared model container
        menuBarController = MenuBarController(appState: appState, modelContainer: modelContainer)

        // Setup global hotkey
        hotkeyManager.startListening { [weak self] in
            self?.menuBarController?.showRecordingWindow()
        }

        // Cleanup old recordings on launch
        AudioRecorder.cleanupOldRecordings()
    }
}
