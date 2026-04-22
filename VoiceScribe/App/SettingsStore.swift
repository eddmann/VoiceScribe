import Foundation

nonisolated enum SettingsKeys {
    static let selectedTranscriptionEngine = "selected_transcription_engine"
    static let smartPasteEnabled = "smart_paste_enabled"
    static let autoStartRecordingFromShortcut = "auto_start_recording_from_shortcut"
    static let parakeetModel = "parakeet_model"
    static let whisperModel = "whisper_model"
    static let localLLMModel = "local_llm_model"
    static let localLLMEnabled = "local_llm_enabled"
    static let historyLimit = "history_limit"
}

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private let userDefaults: UserDefaults

    var selectedTranscriptionEngine: String {
        didSet {
            userDefaults.set(selectedTranscriptionEngine, forKey: SettingsKeys.selectedTranscriptionEngine)
        }
    }

    var smartPasteEnabled: Bool {
        didSet {
            userDefaults.set(smartPasteEnabled, forKey: SettingsKeys.smartPasteEnabled)
        }
    }

    var autoStartRecordingFromShortcut: Bool {
        didSet {
            userDefaults.set(autoStartRecordingFromShortcut, forKey: SettingsKeys.autoStartRecordingFromShortcut)
        }
    }

    var parakeetModel: ParakeetEngine.Model {
        didSet {
            userDefaults.set(parakeetModel.rawValue, forKey: SettingsKeys.parakeetModel)
        }
    }

    var whisperModel: WhisperEngine.Model {
        didSet {
            userDefaults.set(whisperModel.rawValue, forKey: SettingsKeys.whisperModel)
        }
    }

    var localLLMModel: LocalLLMCleanupEngine.Model {
        didSet {
            userDefaults.set(localLLMModel.rawValue, forKey: SettingsKeys.localLLMModel)
        }
    }

    var localLLMEnabled: Bool {
        didSet {
            userDefaults.set(localLLMEnabled, forKey: SettingsKeys.localLLMEnabled)
        }
    }

    var historyLimit: Int {
        didSet {
            userDefaults.set(historyLimit, forKey: SettingsKeys.historyLimit)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let storedEngine = userDefaults.string(forKey: SettingsKeys.selectedTranscriptionEngine)
        let restoredEngine = storedEngine ?? "whisper"
        let validEngine: String
        switch restoredEngine {
        case "whisper", "parakeet":
            validEngine = restoredEngine
        default:
            validEngine = "whisper"
        }
        selectedTranscriptionEngine = validEngine
        if storedEngine == nil || storedEngine != validEngine {
            userDefaults.set(validEngine, forKey: SettingsKeys.selectedTranscriptionEngine)
        }

        if userDefaults.object(forKey: SettingsKeys.smartPasteEnabled) == nil {
            smartPasteEnabled = true
            userDefaults.set(true, forKey: SettingsKeys.smartPasteEnabled)
        } else {
            smartPasteEnabled = userDefaults.bool(forKey: SettingsKeys.smartPasteEnabled)
        }

        autoStartRecordingFromShortcut = userDefaults.bool(forKey: SettingsKeys.autoStartRecordingFromShortcut)

        let parakeetModelRaw = userDefaults.string(forKey: SettingsKeys.parakeetModel)
        let parakeetModelValue = ParakeetEngine.Model(rawValue: parakeetModelRaw ?? "") ?? .englishV2
        parakeetModel = parakeetModelValue
        if parakeetModelRaw == nil {
            userDefaults.set(parakeetModelValue.rawValue, forKey: SettingsKeys.parakeetModel)
        }

        let whisperModelRaw = userDefaults.string(forKey: SettingsKeys.whisperModel)
        let whisperModelValue = WhisperEngine.Model(rawValue: whisperModelRaw ?? "") ?? .small
        whisperModel = whisperModelValue
        if userDefaults.string(forKey: SettingsKeys.whisperModel) == nil {
            userDefaults.set(whisperModelValue.rawValue, forKey: SettingsKeys.whisperModel)
        }

        let localLLMModelRaw = userDefaults.string(forKey: SettingsKeys.localLLMModel)
        let localLLMModelValue = LocalLLMCleanupEngine.Model(rawValue: localLLMModelRaw ?? "") ?? .qwen3_1_7b
        localLLMModel = localLLMModelValue
        if userDefaults.string(forKey: SettingsKeys.localLLMModel) == nil {
            userDefaults.set(localLLMModelValue.rawValue, forKey: SettingsKeys.localLLMModel)
        }

        if userDefaults.object(forKey: SettingsKeys.localLLMEnabled) != nil {
            localLLMEnabled = userDefaults.bool(forKey: SettingsKeys.localLLMEnabled)
        } else {
            localLLMEnabled = false
            userDefaults.set(false, forKey: SettingsKeys.localLLMEnabled)
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
