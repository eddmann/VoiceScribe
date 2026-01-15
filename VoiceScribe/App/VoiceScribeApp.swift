import SwiftUI
import SwiftData

/// VoiceScribe - Modern macOS transcription app
@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Hidden window keeps SwiftUI lifecycle alive for Settings scene
        WindowGroup("VoiceScribeLifecycle") {
            HiddenWindowView()
        }
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)

        // Native Settings scene with tab icons
        Settings {
            SettingsView(appState: .shared)
        }
        .windowResizability(.contentSize)
    }
}

/// App delegate to manage menu bar and global state
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Use shared AppState instance
    let appState = AppState.shared
    var menuBarController: MenuBarController?
    let hotkeyManager = HotkeyManager.shared

    // Create model container
    private lazy var modelContainer: ModelContainer = {
        let schema = Schema([TranscriptionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            appState.setHistoryRepository(HistoryRepository(modelContext: container.mainContext))
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize model container (triggers lazy initialization)
        _ = modelContainer

        // Menu bar app - hide from Dock
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
