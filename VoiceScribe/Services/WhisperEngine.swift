import Foundation
@preconcurrency import WhisperKit
import os.log

/// Local Whisper transcription engine backed by WhisperKit and CoreML.
actor WhisperEngine: TranscriptionEngine {
    nonisolated private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "WhisperEngine"
    )
    let name = "Whisper"
    let identifier = "whisper"
    private var whisperKit: WhisperKit?
    private var currentModel: Model

    private var progressHandler: (@Sendable (String) -> Void)?

    /// Available WhisperKit models tuned for Apple Silicon Macs.
    enum Model: String, CaseIterable {
        case small = "openai_whisper-small"
        case distilLargeV3 = "distil-whisper_distil-large-v3_594MB"
        case largeV3 = "openai_whisper-large-v3-v20240930_626MB"

        var displayName: String {
            switch self {
            case .small:
                return "Fast — Small"
            case .distilLargeV3:
                return "Balanced — Distil Large v3"
            case .largeV3:
                return "Best — Large v3"
            }
        }

        var technicalModelName: String {
            rawValue
        }

        var description: String {
            switch self {
            case .small:
                return "Smallest Whisper option with the lightest local footprint."
            case .distilLargeV3:
                return "Distilled WhisperKit model that balances speed and accuracy well on Apple Silicon."
            case .largeV3:
                return "Highest quality WhisperKit model in this lineup for broader multilingual dictation."
            }
        }

        var approximateSize: String {
            switch self {
            case .small: return "~466 MB"
            case .distilLargeV3: return "~594 MB"
            case .largeV3: return "~626 MB"
            }
        }

        var estimatedBytes: Int64 {
            switch self {
            case .small: return 466 * 1024 * 1024
            case .distilLargeV3: return 594 * 1024 * 1024
            case .largeV3: return 626 * 1024 * 1024
            }
        }

        var huggingFaceURL: URL {
            URL(string: "https://huggingface.co/argmaxinc/whisperkit-coreml/tree/main/\(rawValue)")!
        }
    }

    init() {
        // Load saved model preference or default to small
        if let savedModel = UserDefaults.standard.string(forKey: SettingsKeys.whisperModel),
           let model = Model.allCases.first(where: { $0.rawValue == savedModel }) {
            self.currentModel = model
        } else {
            self.currentModel = .small
            // Save the default
            UserDefaults.standard.set(Model.small.rawValue, forKey: SettingsKeys.whisperModel)
        }
    }

    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async {
        progressHandler = handler
    }

    // MARK: - Model Path Management

    /// Get the local path where WhisperKit stores models
    private nonisolated func getModelPath(for model: Model) -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.rawValue)
    }

    /// Check if a model is downloaded locally
    private nonisolated func isModelDownloadedLocally(_ model: Model) -> Bool {
        guard let modelPath = getModelPath(for: model) else {
            return false
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            // Check for typical model files
            let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
            let hasModelFiles = contents?.contains {
                $0.hasSuffix(".json") || $0.hasSuffix(".bin") || $0.hasSuffix(".mlmodelc")
            } ?? false
            return hasModelFiles
        }

        return false
    }

    /// Set environment variables to force offline operation
    private func setOfflineMode() {
        setenv("HF_HUB_OFFLINE", "1", 1)
        setenv("TRANSFORMERS_OFFLINE", "1", 1)
        setenv("HF_HUB_DISABLE_IMPLICIT_TOKEN", "1", 1)
    }

    // MARK: - TranscriptionEngine Protocol

    var isAvailable: Bool {
        get async {
            // If already initialized, it's available
            if whisperKit != nil {
                return true
            }

            // Check if model is downloaded locally (no network requests)
            return isModelDownloadedLocally(currentModel)
        }
    }

    func validateConfiguration() async throws {
        // Check if model is downloaded locally
        guard isModelDownloadedLocally(currentModel) else {
            throw VoiceScribeError.modelNotFound(modelName: currentModel.displayName)
        }

        // Try to initialize if not already done
        if whisperKit == nil {
            try await initializeWhisperKit()
        }
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        // Check if model is downloaded, if not download it automatically
        if !isModelDownloadedLocally(currentModel) {
            Self.logger.info("Model not found locally, downloading: \(self.currentModel.displayName)")
            progressHandler?("Downloading \(currentModel.displayName) model (\(currentModel.approximateSize))...")

            let progressHandler = self.progressHandler
            try await Self.downloadModel(currentModel) { progress in
                Self.logger.info("Download progress: \(progress)")
                progressHandler?(progress)
            }

            progressHandler?("Model downloaded! Initializing...")
        }

        // Initialize if needed
        if whisperKit == nil {
            progressHandler?("Loading \(currentModel.displayName) model...")
            try await initializeWhisperKit()
        }

        guard let whisper = whisperKit else {
            throw VoiceScribeError.engineNotAvailable(engine: name)
        }

        Self.logger.info("Starting local transcription with model: \(self.currentModel.displayName)")
        progressHandler?("Transcribing audio...")

        do {
            // Transcribe audio file
            let results = try await whisper.transcribe(audioPath: audioURL.path)

            // Combine all segments into single text
            let text = results.map { $0.text }.joined(separator: " ")
            Self.logger.info("Local transcription successful: \(text.count) chars")
            let transcribedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let segments = results.map { segment in
                TranscriptionResult.Segment(text: segment.text)
            }

            guard !transcribedText.isEmpty else {
                return .ignored(.noSpeechDetected, segments: segments)
            }

            guard !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .ignored(.emptyTranscription, segments: segments)
            }

            return .success(transcribedText, segments: segments)

        } catch let error as VoiceScribeError {
            throw error
        } catch {
            Self.logger.error("WhisperKit transcription error: \(error.localizedDescription)")
            throw VoiceScribeError.transcriptionFailed(
                engine: name,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Model Initialization

    /// Initialize WhisperKit with the selected model from local storage
    private func initializeWhisperKit() async throws {
        Self.logger.info("Initializing WhisperKit with model: \(self.currentModel.displayName)")

        // Ensure model is downloaded
        guard isModelDownloadedLocally(currentModel) else {
            throw VoiceScribeError.modelNotFound(modelName: currentModel.displayName)
        }

        // Set environment variables to force offline operation
        setOfflineMode()

        do {
            // Try to load from local model path first
            if let localModelPath = getModelPath(for: currentModel) {
                Self.logger.info("Loading model from: \(localModelPath.path)")
                let config = WhisperKitConfig(modelFolder: localModelPath.path)
                whisperKit = try await WhisperKit(config)
            } else {
                // Fallback to model name (with offline env vars set)
                let config = WhisperKitConfig(model: currentModel.rawValue)
                whisperKit = try await WhisperKit(config)
            }

            Self.logger.info("WhisperKit initialized successfully")

        } catch {
            Self.logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")

            // Provide helpful error messages
            if error.localizedDescription.contains("offline") ||
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") {
                throw VoiceScribeError.modelNotFound(modelName: currentModel.displayName)
            }

            throw VoiceScribeError.transcriptionFailed(
                engine: name,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Model Management

    /// Change the model being used
    func changeModel(to model: Model) async throws {
        currentModel = model
        whisperKit = nil
        try await validateConfiguration()
    }

    /// Reload the model from user preferences
    func reloadModelFromPreferences() async {
        if let savedModel = UserDefaults.standard.string(forKey: SettingsKeys.whisperModel),
           let model = Model.allCases.first(where: { $0.rawValue == savedModel }),
           model != currentModel {
            Self.logger.info("Reloading model from preferences: \(model.displayName)")
            currentModel = model
            // Clear whisperKit to force re-initialization with new model
            whisperKit = nil
        }
    }

    func currentModelName() async -> String {
        currentModel.displayName
    }

    /// Download a model if not already available
    static func downloadModel(_ model: Model, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        Self.logger.info("Downloading model: \(model.displayName)")

        progressCallback?("Preparing to download \(model.displayName)...")

        do {
            // WhisperKit automatically downloads models when initialized
            // Don't set offline env vars for downloads
            let config = WhisperKitConfig(model: model.rawValue)
            progressCallback?("Downloading \(model.approximateSize)...")

            _ = try await WhisperKit(config)

            progressCallback?("Download complete!")
            Self.logger.info("Model downloaded successfully: \(model.displayName)")

        } catch {
            Self.logger.error("Model download failed: \(error.localizedDescription)")
            throw VoiceScribeError.modelDownloadFailed(
                modelName: model.displayName,
                reason: error.localizedDescription
            )
        }
    }

    /// Get list of downloaded models
    static func getDownloadedModels() -> [Model] {
        return Model.allCases.filter { model in
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return false
            }

            let modelPath = documentsPath
                .appendingPathComponent("huggingface")
                .appendingPathComponent("models")
                .appendingPathComponent("argmaxinc")
                .appendingPathComponent("whisperkit-coreml")
                .appendingPathComponent(model.rawValue)

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)

            if exists && isDirectory.boolValue {
                let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
                let hasModelFiles = contents?.contains {
                    $0.hasSuffix(".json") || $0.hasSuffix(".bin") || $0.hasSuffix(".mlmodelc")
                } ?? false
                return hasModelFiles
            }

            return false
        }
    }

    /// Delete a downloaded model
    static func deleteModel(_ model: Model) throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw VoiceScribeError.invalidConfiguration(reason: "Cannot find Documents directory")
        }

        let modelPath = documentsPath
            .appendingPathComponent("huggingface")
            .appendingPathComponent("models")
            .appendingPathComponent("argmaxinc")
            .appendingPathComponent("whisperkit-coreml")
            .appendingPathComponent(model.rawValue)

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
            Self.logger.info("Deleted model: \(model.displayName)")
        }
    }
}
