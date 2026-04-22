import XCTest
import ComposableArchitecture
@testable import VoiceScribe

@MainActor
final class SettingsFeatureTests: XCTestCase {
    func test_selectionActions_persistToSettingsStore() async {
        let suiteName = "SettingsFeatureTests.selection.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(userDefaults: defaults)

        let store = TestStore(initialState: SettingsFeature.State(settings: settings)) {
            SettingsFeature(
                settings: settings,
                launchAtLoginClient: .init(
                    isEnabled: { false },
                    register: {},
                    unregister: {}
                ),
                accessibilityClient: .init(
                    hasPermission: { false },
                    openSettings: {}
                )
            )
        }

        await store.send(.transcriptionEngineSelected("parakeet")) {
            $0.selectedTranscriptionEngine = "parakeet"
        }
        await store.send(.parakeetModelSelected(.multilingualV3)) {
            $0.parakeetModel = .multilingualV3
        }
        await store.send(.whisperModelSelected(.distilLargeV3)) {
            $0.whisperModel = .distilLargeV3
        }
        await store.send(.localLLMEnabledChanged(true)) {
            $0.localLLMEnabled = true
        }
        await store.send(.localLLMModelSelected(.qwen3_4b)) {
            $0.localLLMModel = .qwen3_4b
        }
        await store.send(.smartPasteEnabledChanged(false)) {
            $0.smartPasteEnabled = false
        }
        await store.send(.historyLimitSelected(50)) {
            $0.historyLimit = 50
        }

        XCTAssertEqual(settings.selectedTranscriptionEngine, "parakeet")
        XCTAssertEqual(settings.parakeetModel, .multilingualV3)
        XCTAssertEqual(settings.whisperModel, .distilLargeV3)
        XCTAssertEqual(settings.localLLMEnabled, true)
        XCTAssertEqual(settings.localLLMModel, .qwen3_4b)
        XCTAssertEqual(settings.smartPasteEnabled, false)
        XCTAssertEqual(settings.historyLimit, 50)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_appeared_syncsPermissionsLaunchAtLoginAndPersistedSettings() async {
        let suiteName = "SettingsFeatureTests.appeared.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set("parakeet", forKey: SettingsKeys.selectedTranscriptionEngine)
        defaults.set(ParakeetEngine.Model.multilingualV3.rawValue, forKey: SettingsKeys.parakeetModel)
        defaults.set(true, forKey: SettingsKeys.localLLMEnabled)
        defaults.set(LocalLLMCleanupEngine.Model.llama3_2_3b.rawValue, forKey: SettingsKeys.localLLMModel)
        defaults.set(10, forKey: SettingsKeys.historyLimit)
        let settings = SettingsStore(userDefaults: defaults)

        let store = TestStore(initialState: SettingsFeature.State(settings: settings)) {
            SettingsFeature(
                settings: settings,
                launchAtLoginClient: .init(
                    isEnabled: { true },
                    register: {},
                    unregister: {}
                ),
                accessibilityClient: .init(
                    hasPermission: { true },
                    openSettings: {}
                )
            )
        }

        await store.send(.appeared) {
            $0.selectedTranscriptionEngine = "parakeet"
            $0.parakeetModel = .multilingualV3
            $0.localLLMEnabled = true
            $0.localLLMModel = .llama3_2_3b
            $0.historyLimit = 10
            $0.downloadedParakeetModels = Set(ParakeetEngine.getDownloadedModels())
            $0.downloadedWhisperModels = Set(WhisperEngine.getDownloadedModels())
            $0.downloadedLocalLLMModels = Set(LocalLLMCleanupEngine.getDownloadedModels())
            $0.hasAccessibilityPermission = true
            $0.launchAtLogin = true
        }

        await store.send(.disappeared)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_downloadFinishedError_updatesDownloadStateAndErrorMessage() async {
        let suiteName = "SettingsFeatureTests.download.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let settings = SettingsStore(userDefaults: defaults)
        var initialState = SettingsFeature.State(settings: settings)
        initialState.downloadingWhisperModels = [.small]

        let store = TestStore(initialState: initialState) {
            SettingsFeature(
                settings: settings,
                launchAtLoginClient: .init(
                    isEnabled: { false },
                    register: {},
                    unregister: {}
                ),
                accessibilityClient: .init(
                    hasPermission: { false },
                    openSettings: {}
                )
            )
        }

        await store.send(.downloadWhisperModelFinished(.small, "Download failed")) {
            $0.downloadingWhisperModels = []
            $0.downloadError = "Download failed"
        }

        defaults.removePersistentDomain(forName: suiteName)
    }
}
