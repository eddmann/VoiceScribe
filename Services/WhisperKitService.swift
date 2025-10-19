import Foundation
@preconcurrency import WhisperKit
import os.log

private let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "WhisperKitService")

/// Local WhisperKit transcription service (CoreML-based)
@MainActor
final class WhisperKitService: TranscriptionService {
    let name = "Local WhisperKit"
    let identifier = "whisperkit"
    let requiresAPIKey = false

    nonisolated(unsafe) private var whisperKit: WhisperKit?
    private var currentModel: Model

    /// Optional progress callback for transcription operations
    var progressCallback: (@MainActor (String) -> Void)?

    /// Available WhisperKit models (from smallest to largest)
    enum Model: String, CaseIterable {
        case tiny = "openai_whisper-tiny"
        case base = "openai_whisper-base"
        case small = "openai_whisper-small"
        case medium = "openai_whisper-medium"

        var displayName: String {
            switch self {
            case .tiny: return "Tiny (fast, less accurate)"
            case .base: return "Base (balanced)"
            case .small: return "Small (good quality)"
            case .medium: return "Medium (best quality)"
            }
        }

        var approximateSize: String {
            switch self {
            case .tiny: return "~40 MB"
            case .base: return "~150 MB"
            case .small: return "~500 MB"
            case .medium: return "~1.5 GB"
            }
        }

        var estimatedBytes: Int64 {
            switch self {
            case .tiny: return 39 * 1024 * 1024
            case .base: return 142 * 1024 * 1024
            case .small: return 466 * 1024 * 1024
            case .medium: return 1536 * 1024 * 1024
            }
        }
    }

    init() {
        // Load saved model preference or default to tiny
        if let savedModel = UserDefaults.standard.string(forKey: "whisperkit_model"),
           let model = Model.allCases.first(where: { $0.rawValue == savedModel }) {
            self.currentModel = model
        } else {
            self.currentModel = .tiny
            // Save the default
            UserDefaults.standard.set(Model.tiny.rawValue, forKey: "whisperkit_model")
        }
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

    // MARK: - TranscriptionService Protocol

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

    func transcribe(audioURL: URL) async throws -> String {
        // Check if model is downloaded, if not download it automatically
        if !isModelDownloadedLocally(currentModel) {
            logger.info("Model not found locally, downloading: \(self.currentModel.displayName)")
            progressCallback?("Downloading \(currentModel.displayName) model (\(currentModel.approximateSize))...")

            try await Self.downloadModel(currentModel) { progress in
                Task { @MainActor in
                    logger.info("Download progress: \(progress)")
                    self.progressCallback?(progress)
                }
            }

            progressCallback?("Model downloaded! Initializing...")
        }

        // Initialize if needed
        if whisperKit == nil {
            progressCallback?("Loading \(currentModel.displayName) model...")
            try await initializeWhisperKit()
        }

        guard let whisper = whisperKit else {
            throw VoiceScribeError.serviceNotAvailable(service: name)
        }

        logger.info("Starting local transcription with model: \(self.currentModel.displayName)")
        progressCallback?("Transcribing audio...")

        do {
            // Transcribe audio file
            let results = try await whisper.transcribe(audioPath: audioURL.path)

            // Combine all segments into single text
            let text = results.map { $0.text }.joined(separator: " ")

            guard !text.isEmpty else {
                throw VoiceScribeError.noAudioRecorded
            }

            logger.info("Local transcription successful: \(text.count) chars")
            return text.trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            logger.error("WhisperKit transcription error: \(error.localizedDescription)")
            throw VoiceScribeError.transcriptionFailed(
                service: name,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Model Initialization

    /// Initialize WhisperKit with the selected model from local storage
    private func initializeWhisperKit() async throws {
        logger.info("Initializing WhisperKit with model: \(self.currentModel.displayName)")

        // Ensure model is downloaded
        guard isModelDownloadedLocally(currentModel) else {
            throw VoiceScribeError.modelNotFound(modelName: currentModel.displayName)
        }

        // Set environment variables to force offline operation
        setOfflineMode()

        do {
            // Try to load from local model path first
            if let localModelPath = getModelPath(for: currentModel) {
                logger.info("Loading model from: \(localModelPath.path)")
                let config = WhisperKitConfig(modelFolder: localModelPath.path)
                whisperKit = try await WhisperKit(config)
            } else {
                // Fallback to model name (with offline env vars set)
                let config = WhisperKitConfig(model: currentModel.rawValue)
                whisperKit = try await WhisperKit(config)
            }

            logger.info("WhisperKit initialized successfully")

        } catch {
            logger.error("Failed to initialize WhisperKit: \(error.localizedDescription)")

            // Provide helpful error messages
            if error.localizedDescription.contains("offline") ||
               error.localizedDescription.contains("network") ||
               error.localizedDescription.contains("connection") {
                throw VoiceScribeError.modelNotFound(modelName: currentModel.displayName)
            }

            throw VoiceScribeError.transcriptionFailed(
                service: name,
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
    func reloadModelFromPreferences() {
        if let savedModel = UserDefaults.standard.string(forKey: "whisperkit_model"),
           let model = Model.allCases.first(where: { $0.rawValue == savedModel }),
           model != currentModel {
            logger.info("Reloading model from preferences: \(model.displayName)")
            currentModel = model
            // Clear whisperKit to force re-initialization with new model
            whisperKit = nil
        }
    }

    /// Download a model if not already available
    static func downloadModel(_ model: Model, progressCallback: (@Sendable (String) -> Void)? = nil) async throws {
        logger.info("Downloading model: \(model.displayName)")

        progressCallback?("Preparing to download \(model.displayName)...")

        do {
            // WhisperKit automatically downloads models when initialized
            // Don't set offline env vars for downloads
            let config = WhisperKitConfig(model: model.rawValue)
            progressCallback?("Downloading \(model.approximateSize)...")

            _ = try await WhisperKit(config)

            progressCallback?("Download complete!")
            logger.info("Model downloaded successfully: \(model.displayName)")

        } catch {
            logger.error("Model download failed: \(error.localizedDescription)")
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
            logger.info("Deleted model: \(model.displayName)")
        }
    }
}
