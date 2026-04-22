import XCTest
import ComposableArchitecture
@testable import VoiceScribe

@MainActor
final class AppFeatureTests: XCTestCase {
    func test_settingsHistoryLimitSelection_updatesHistoryFeatureLimit() async {
        let suiteName = "AppFeatureTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature(
                pipeline: PipelineFeature(
                    recordingClient: .testValue,
                    pipelineSettingsClient: .testValue,
                    transcriptionClient: .testValue,
                    cleanupClient: .testValue,
                    completionClient: .testValue,
                    autoResetDelay: nil,
                    audioMeteringInterval: nil
                ),
                settings: SettingsFeature(settings: SettingsStore(userDefaults: defaults)),
                history: HistoryFeature()
            )
        }

        await store.send(.settings(.historyLimitSelected(50))) {
            $0.settings.historyLimit = 50
            $0.history.historyLimit = 50
        }

        defaults.removePersistentDomain(forName: suiteName)
    }
}
