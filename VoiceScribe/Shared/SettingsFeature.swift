import ComposableArchitecture
import Foundation
import Perception
import ServiceManagement
import os.log

private let settingsLogger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "Settings")

@MainActor
struct LaunchAtLoginClient {
    var isEnabled: () -> Bool
    var register: () throws -> Void
    var unregister: () throws -> Void
}

@MainActor
extension LaunchAtLoginClient {
    static let liveValue = LaunchAtLoginClient(
        isEnabled: { SMAppService.mainApp.status == .enabled },
        register: { try SMAppService.mainApp.register() },
        unregister: { try SMAppService.mainApp.unregister() }
    )
}

@MainActor
struct AccessibilityPermissionClient {
    var hasPermission: () -> Bool
    var openSettings: () -> Void
}

@MainActor
extension AccessibilityPermissionClient {
    static let liveValue = AccessibilityPermissionClient(
        hasPermission: { PasteSimulator.shared.hasAccessibilityPermission },
        openSettings: { PasteSimulator.shared.openAccessibilitySettings() }
    )
}

struct SettingsFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        var selectedTranscriptionEngine: String
        var whisperModel: WhisperEngine.Model
        var parakeetModel: ParakeetEngine.Model
        var localLLMEnabled: Bool
        var localLLMModel: LocalLLMCleanupEngine.Model
        var smartPasteEnabled: Bool
        var autoStartRecordingFromShortcut: Bool
        var historyLimit: Int
        var downloadingParakeetModels: Set<ParakeetEngine.Model> = []
        var downloadedParakeetModels: Set<ParakeetEngine.Model> = []
        var downloadingWhisperModels: Set<WhisperEngine.Model> = []
        var downloadedWhisperModels: Set<WhisperEngine.Model> = []
        var downloadingLocalLLMModels: Set<LocalLLMCleanupEngine.Model> = []
        var downloadedLocalLLMModels: Set<LocalLLMCleanupEngine.Model> = []
        var downloadError: String?
        var hasAccessibilityPermission = false
        var launchAtLogin = false

        init(settings: SettingsStore = .shared) {
            selectedTranscriptionEngine = Self.normalizedTranscriptionEngine(settings.selectedTranscriptionEngine)
            whisperModel = settings.whisperModel
            parakeetModel = settings.parakeetModel
            localLLMEnabled = settings.localLLMEnabled
            localLLMModel = settings.localLLMModel
            smartPasteEnabled = settings.smartPasteEnabled
            autoStartRecordingFromShortcut = settings.autoStartRecordingFromShortcut
            historyLimit = settings.historyLimit
        }

        private static func normalizedTranscriptionEngine(_ value: String) -> String {
            switch value {
            case "parakeet":
                return "parakeet"
            default:
                return "whisper"
            }
        }
    }

    enum Action: Equatable {
        case appeared
        case disappeared
        case permissionRefreshed
        case transcriptionEngineSelected(String)
        case whisperModelSelected(WhisperEngine.Model)
        case parakeetModelSelected(ParakeetEngine.Model)
        case localLLMEnabledChanged(Bool)
        case localLLMModelSelected(LocalLLMCleanupEngine.Model)
        case smartPasteEnabledChanged(Bool)
        case autoStartRecordingFromShortcutChanged(Bool)
        case historyLimitSelected(Int)
        case launchAtLoginChanged(Bool)
        case openAccessibilitySettingsTapped
        case downloadWhisperModelTapped(WhisperEngine.Model)
        case downloadWhisperModelFinished(WhisperEngine.Model, String?)
        case deleteWhisperModelTapped(WhisperEngine.Model)
        case deleteWhisperModelFinished(String?)
        case downloadParakeetModelTapped(ParakeetEngine.Model)
        case downloadParakeetModelFinished(ParakeetEngine.Model, String?)
        case deleteParakeetModelTapped(ParakeetEngine.Model)
        case deleteParakeetModelFinished(String?)
        case downloadLocalLLMModelTapped(LocalLLMCleanupEngine.Model)
        case downloadLocalLLMModelFinished(LocalLLMCleanupEngine.Model, String?)
        case deleteLocalLLMModelTapped(LocalLLMCleanupEngine.Model)
        case deleteLocalLLMModelFinished(String?)
    }

    var settings: SettingsStore = .shared
    var launchAtLoginClient: LaunchAtLoginClient = .liveValue
    var accessibilityClient: AccessibilityPermissionClient = .liveValue

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .appeared:
                syncFromSettings(into: &state)
                refreshDownloads(into: &state)
                state.hasAccessibilityPermission = accessibilityClient.hasPermission()
                state.launchAtLogin = launchAtLoginClient.isEnabled()

                return .run { send in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { break }
                        await send(.permissionRefreshed)
                    }
                }
                .cancellable(id: "settings.permissionPolling")

            case .disappeared:
                return .cancel(id: "settings.permissionPolling")

            case .permissionRefreshed:
                state.hasAccessibilityPermission = accessibilityClient.hasPermission()
                return .none

            case .transcriptionEngineSelected(let engine):
                let normalized = normalizedTranscriptionEngine(engine)
                state.selectedTranscriptionEngine = normalized
                settings.selectedTranscriptionEngine = normalized
                return .none

            case .whisperModelSelected(let model):
                state.whisperModel = model
                settings.whisperModel = model
                return .none

            case .parakeetModelSelected(let model):
                state.parakeetModel = model
                settings.parakeetModel = model
                return .none

            case .localLLMEnabledChanged(let enabled):
                state.localLLMEnabled = enabled
                settings.localLLMEnabled = enabled
                return .none

            case .localLLMModelSelected(let model):
                state.localLLMModel = model
                settings.localLLMModel = model
                return .none

            case .smartPasteEnabledChanged(let enabled):
                state.smartPasteEnabled = enabled
                settings.smartPasteEnabled = enabled
                return .none

            case .autoStartRecordingFromShortcutChanged(let enabled):
                state.autoStartRecordingFromShortcut = enabled
                settings.autoStartRecordingFromShortcut = enabled
                return .none

            case .historyLimitSelected(let limit):
                state.historyLimit = limit
                settings.historyLimit = limit
                return .none

            case .launchAtLoginChanged(let enabled):
                state.launchAtLogin = enabled

                do {
                    if enabled {
                        try launchAtLoginClient.register()
                    } else {
                        try launchAtLoginClient.unregister()
                    }
                } catch {
                    settingsLogger.error("Failed to update launch at login: \(error.localizedDescription)")
                    state.launchAtLogin = launchAtLoginClient.isEnabled()
                }
                return .none

            case .openAccessibilitySettingsTapped:
                accessibilityClient.openSettings()
                return .none

            case .downloadWhisperModelTapped(let model):
                state.downloadingWhisperModels.insert(model)
                state.downloadError = nil
                return .run { send in
                    do {
                        try await WhisperEngine.downloadModel(model)
                        await send(.downloadWhisperModelFinished(model, nil))
                    } catch {
                        await send(.downloadWhisperModelFinished(model, error.localizedDescription))
                    }
                }

            case .downloadWhisperModelFinished(let model, let error):
                state.downloadingWhisperModels.remove(model)
                if let error {
                    state.downloadError = error
                } else {
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                }
                return .none

            case .deleteWhisperModelTapped(let model):
                do {
                    try WhisperEngine.deleteModel(model)
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                    return .none
                } catch {
                    return .send(.deleteWhisperModelFinished(error.localizedDescription))
                }

            case .deleteWhisperModelFinished(let error):
                state.downloadError = error
                return .none

            case .downloadParakeetModelTapped(let model):
                state.downloadingParakeetModels.insert(model)
                state.downloadError = nil
                return .run { send in
                    do {
                        try await ParakeetEngine.downloadModel(model)
                        await send(.downloadParakeetModelFinished(model, nil))
                    } catch {
                        await send(.downloadParakeetModelFinished(model, error.localizedDescription))
                    }
                }

            case .downloadParakeetModelFinished(let model, let error):
                state.downloadingParakeetModels.remove(model)
                if let error {
                    state.downloadError = error
                } else {
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                }
                return .none

            case .deleteParakeetModelTapped(let model):
                do {
                    try ParakeetEngine.deleteModel(model)
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                    return .none
                } catch {
                    return .send(.deleteParakeetModelFinished(error.localizedDescription))
                }

            case .deleteParakeetModelFinished(let error):
                state.downloadError = error
                return .none

            case .downloadLocalLLMModelTapped(let model):
                state.downloadingLocalLLMModels.insert(model)
                state.downloadError = nil
                return .run { send in
                    do {
                        try await LocalLLMCleanupEngine.shared.downloadModel(model)
                        await send(.downloadLocalLLMModelFinished(model, nil))
                    } catch {
                        await send(.downloadLocalLLMModelFinished(model, error.localizedDescription))
                    }
                }

            case .downloadLocalLLMModelFinished(let model, let error):
                state.downloadingLocalLLMModels.remove(model)
                if let error {
                    state.downloadError = error
                } else {
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                }
                return .none

            case .deleteLocalLLMModelTapped(let model):
                return .run { send in
                    do {
                        try await LocalLLMCleanupEngine.shared.deleteModel(model)
                        await send(.deleteLocalLLMModelFinished(nil))
                    } catch {
                        await send(.deleteLocalLLMModelFinished(error.localizedDescription))
                    }
                }

            case .deleteLocalLLMModelFinished(let error):
                if let error {
                    state.downloadError = error
                } else {
                    refreshDownloads(into: &state)
                    state.downloadError = nil
                }
                return .none
            }
        }
    }

    private func normalizedTranscriptionEngine(_ value: String) -> String {
        switch value {
        case "parakeet":
            return "parakeet"
        default:
            return "whisper"
        }
    }

    private func syncFromSettings(into state: inout State) {
        state.selectedTranscriptionEngine = normalizedTranscriptionEngine(settings.selectedTranscriptionEngine)
        state.whisperModel = settings.whisperModel
        state.parakeetModel = settings.parakeetModel
        state.localLLMEnabled = settings.localLLMEnabled
        state.localLLMModel = settings.localLLMModel
        state.smartPasteEnabled = settings.smartPasteEnabled
        state.autoStartRecordingFromShortcut = settings.autoStartRecordingFromShortcut
        state.historyLimit = settings.historyLimit
    }

    private func refreshDownloads(into state: inout State) {
        state.downloadedParakeetModels = Set(ParakeetEngine.getDownloadedModels())
        state.downloadedWhisperModels = Set(WhisperEngine.getDownloadedModels())
        state.downloadedLocalLLMModels = Set(LocalLLMCleanupEngine.getDownloadedModels())
    }
}
