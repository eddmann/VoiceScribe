import Foundation

nonisolated enum SettingsKeys {
    static let selectedServiceIdentifier = "selected_service"
    static let smartPasteEnabled = "smart_paste_enabled"
    static let openAIModel = "openai_model"
    static let whisperKitModel = "whisperkit_model"
    static let mlxModel = "mlx_model"
    static let openAIPostProcessEnabled = "openai_post_process_enabled"
    static let whisperKitPostProcessEnabled = "whisperkit_post_process_enabled"
    static let historyLimit = "history_limit"
}

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let userDefaults: UserDefaults

    var selectedServiceIdentifier: String {
        didSet {
            userDefaults.set(selectedServiceIdentifier, forKey: SettingsKeys.selectedServiceIdentifier)
        }
    }

    var smartPasteEnabled: Bool {
        didSet {
            userDefaults.set(smartPasteEnabled, forKey: SettingsKeys.smartPasteEnabled)
        }
    }

    var openAIModel: OpenAIService.Model {
        didSet {
            userDefaults.set(openAIModel.rawValue, forKey: SettingsKeys.openAIModel)
        }
    }

    var whisperKitModel: WhisperKitService.Model {
        didSet {
            userDefaults.set(whisperKitModel.rawValue, forKey: SettingsKeys.whisperKitModel)
        }
    }

    var mlxModel: MLXService.Model {
        didSet {
            userDefaults.set(mlxModel.rawValue, forKey: SettingsKeys.mlxModel)
        }
    }

    var openAIPostProcessEnabled: Bool {
        didSet {
            userDefaults.set(openAIPostProcessEnabled, forKey: SettingsKeys.openAIPostProcessEnabled)
        }
    }

    var whisperKitPostProcessEnabled: Bool {
        didSet {
            userDefaults.set(whisperKitPostProcessEnabled, forKey: SettingsKeys.whisperKitPostProcessEnabled)
        }
    }

    var historyLimit: Int {
        didSet {
            userDefaults.set(historyLimit, forKey: SettingsKeys.historyLimit)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let storedService = userDefaults.string(forKey: SettingsKeys.selectedServiceIdentifier)
        let validService = (storedService != nil && !storedService!.isEmpty) ? storedService! : "whisperkit"
        selectedServiceIdentifier = validService
        if storedService == nil || storedService!.isEmpty {
            userDefaults.set(validService, forKey: SettingsKeys.selectedServiceIdentifier)
        }

        if userDefaults.object(forKey: SettingsKeys.smartPasteEnabled) == nil {
            smartPasteEnabled = true
            userDefaults.set(true, forKey: SettingsKeys.smartPasteEnabled)
        } else {
            smartPasteEnabled = userDefaults.bool(forKey: SettingsKeys.smartPasteEnabled)
        }

        let openAIModelRaw = userDefaults.string(forKey: SettingsKeys.openAIModel)
        let openAIModelValue = OpenAIService.Model(rawValue: openAIModelRaw ?? "") ?? .whisper1
        openAIModel = openAIModelValue
        if openAIModelRaw == nil {
            userDefaults.set(openAIModelValue.rawValue, forKey: SettingsKeys.openAIModel)
        }

        let whisperKitModelRaw = userDefaults.string(forKey: SettingsKeys.whisperKitModel)
        let whisperKitModelValue = WhisperKitService.Model(rawValue: whisperKitModelRaw ?? "") ?? .base
        whisperKitModel = whisperKitModelValue
        if whisperKitModelRaw == nil {
            userDefaults.set(whisperKitModelValue.rawValue, forKey: SettingsKeys.whisperKitModel)
        }

        let mlxModelRaw = userDefaults.string(forKey: SettingsKeys.mlxModel)
        let mlxModelValue = MLXService.Model(rawValue: mlxModelRaw ?? "") ?? .qwen25_0_5b
        mlxModel = mlxModelValue
        if mlxModelRaw == nil {
            userDefaults.set(mlxModelValue.rawValue, forKey: SettingsKeys.mlxModel)
        }

        openAIPostProcessEnabled = userDefaults.bool(forKey: SettingsKeys.openAIPostProcessEnabled)
        if userDefaults.object(forKey: SettingsKeys.openAIPostProcessEnabled) == nil {
            userDefaults.set(false, forKey: SettingsKeys.openAIPostProcessEnabled)
        }

        whisperKitPostProcessEnabled = userDefaults.bool(forKey: SettingsKeys.whisperKitPostProcessEnabled)
        if userDefaults.object(forKey: SettingsKeys.whisperKitPostProcessEnabled) == nil {
            userDefaults.set(false, forKey: SettingsKeys.whisperKitPostProcessEnabled)
        }

        if userDefaults.object(forKey: SettingsKeys.historyLimit) == nil {
            historyLimit = 25
            userDefaults.set(25, forKey: SettingsKeys.historyLimit)
        } else {
            let storedLimit = userDefaults.integer(forKey: SettingsKeys.historyLimit)
            historyLimit = storedLimit > 0 ? storedLimit : 25
            if storedLimit <= 0 {
                userDefaults.set(25, forKey: SettingsKeys.historyLimit)
            }
        }
    }
}
