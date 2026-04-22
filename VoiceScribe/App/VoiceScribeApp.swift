import SwiftUI
import SwiftData
import ComposableArchitecture

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
            SettingsView(
                store: appDelegate.appStore.scope(
                    state: \.settings,
                    action: { .settings($0) }
                )
            )
        }
        .windowResizability(.contentSize)
    }
}

/// App delegate to manage menu bar and global state
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
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
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    lazy var appStore: StoreOf<AppFeature> = {
        let historyRepository = HistoryRepository(modelContext: modelContainer.mainContext)
        let clipboardClient = PasteboardClipboardClient()
        let focusClient = AppFocusManager.shared
        let pasteClient = PasteSimulator.shared

        return Store(initialState: .init()) {
            AppFeature(
                pipeline: PipelineFeature(
                    completionClient: AppCompletionClient.live(
                        historyRepository: historyRepository,
                        clipboardClient: clipboardClient,
                        focusClient: focusClient,
                        pasteClient: pasteClient
                    )
                )
            )
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
        menuBarController = MenuBarController(
            store: appStore,
            modelContainer: modelContainer
        )

        #if DEBUG
        if let demoMode {
            configureDemoMode(demoMode)
            return
        }
        #endif

        // Normal startup flow
        // Setup global hotkey
        hotkeyManager.startListening { [weak self] in
            self?.menuBarController?.handleGlobalRecordingShortcut()
        }

        // Cleanup old recordings on launch
        AudioRecorder.cleanupOldRecordings()
    }

    #if DEBUG
    private func configureDemoMode(_ mode: DemoMode) {
        // Populate history if needed
        if mode == .historyPopulated {
            DemoDataFactory.populateHistory(context: modelContainer.mainContext)
        }

        // Show appropriate window
        if mode.showsHistoryWindow {
            menuBarController?.showHistory()
        } else {
            menuBarController?.showRecordingWindowForDemo(mode: mode)
        }
    }
    #endif
}
