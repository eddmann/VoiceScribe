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

    #if DEBUG
    private var demoMode: DemoMode?
    #endif

    // Create model container
    private lazy var modelContainer: ModelContainer = {
        let schema = Schema([TranscriptionRecord.self])

        #if DEBUG
        // Use in-memory storage for demo modes to avoid polluting real data
        let isInMemory = demoMode != nil
        #else
        let isInMemory = false
        #endif

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isInMemory)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            appState.setHistoryRepository(HistoryRepository(modelContext: container.mainContext))
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        demoMode = DemoMode.fromArguments()
        #endif

        // Initialize model container (triggers lazy initialization)
        _ = modelContainer

        // Menu bar app - hide from Dock
        NSApplication.shared.setActivationPolicy(.accessory)

        // Setup menu bar with shared model container
        menuBarController = MenuBarController(appState: appState, modelContainer: modelContainer)

        #if DEBUG
        if let demoMode {
            configureDemoMode(demoMode)
            return
        }
        #endif

        // Normal startup flow
        // Setup global hotkey
        hotkeyManager.startListening { [weak self] in
            self?.menuBarController?.showRecordingWindow()
        }

        // Cleanup old recordings on launch
        AudioRecorder.cleanupOldRecordings()
    }

    #if DEBUG
    private func configureDemoMode(_ mode: DemoMode) {
        // Configure app state for the demo mode
        DemoDataFactory.configure(appState, for: mode)

        // Populate history if needed
        if mode == .historyPopulated {
            DemoDataFactory.populateHistory(context: modelContainer.mainContext)
        }

        // Show appropriate window
        if mode.showsHistoryWindow {
            menuBarController?.showHistory()
        } else {
            menuBarController?.showRecordingWindowForDemo()
        }
    }
    #endif
}
