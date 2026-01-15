import Foundation
import os.log
import MLX
import MLXRandom
import MLXLLM
import MLXLMCommon

/// Local MLX-based LLM service for post-processing transcriptions
actor MLXService {
    nonisolated private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "MLXService"
    )
    static let shared = MLXService()

    /// Available MLX models for post-processing
    enum Model: String, CaseIterable {
        case qwen25_0_5b = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        case llama3_2_3b = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case phi3_5_mini = "mlx-community/Phi-3.5-mini-instruct-4bit"

        var displayName: String {
            switch self {
            case .qwen25_0_5b:
                return "Qwen 2.5 0.5B (Fast)"
            case .llama3_2_3b:
                return "Llama 3.2 3B (Balanced)"
            case .phi3_5_mini:
                return "Phi-3.5 Mini (Quality)"
            }
        }

        var description: String {
            switch self {
            case .qwen25_0_5b:
                return "Smallest model • ~300MB • Very fast, surprisingly capable"
            case .llama3_2_3b:
                return "Medium model • ~1.8GB • Excellent balance of speed and quality"
            case .phi3_5_mini:
                return "Largest model • ~2.4GB • Best accuracy, perfect benchmark scores"
            }
        }

        var approximateSize: String {
            switch self {
            case .qwen25_0_5b:
                return "~300 MB"
            case .llama3_2_3b:
                return "~1.8 GB"
            case .phi3_5_mini:
                return "~2.4 GB"
            }
        }
    }

    nonisolated private var currentModel: Model {
        if let savedModel = UserDefaults.standard.string(forKey: SettingsKeys.mlxModel),
           let model = Model(rawValue: savedModel) {
            return model
        }
        return .qwen25_0_5b // Default to smallest/fastest
    }

    /// Get the currently selected model
    nonisolated func getCurrentModel() -> Model {
        return currentModel
    }

    private var progressHandler: (@Sendable (String) -> Void)?

    private init() {}

    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) {
        progressHandler = handler
    }

    // MARK: - Model Management

    /// Check if MLX is available (Apple Silicon only)
    nonisolated var isAvailable: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// Get the local path where MLX models are stored
    private nonisolated func getModelPath(for model: Model) -> URL? {
        guard let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        // MLXLLM downloads to the sandboxed cache directory:
        // ~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/mlx-community/{model-name}
        return cachePath
            .appendingPathComponent("models")
            .appendingPathComponent(model.rawValue)
    }

    /// Check if a model is downloaded locally
    nonisolated func isModelDownloaded(_ model: Model) -> Bool {
        guard let modelPath = getModelPath(for: model) else {
            return false
        }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelPath.path, isDirectory: &isDirectory)

        if exists && isDirectory.boolValue {
            // Check for typical model files
            let contents = try? FileManager.default.contentsOfDirectory(atPath: modelPath.path)
            let hasModelFiles = contents?.contains {
                $0.hasSuffix(".safetensors") || $0.hasSuffix(".json") || $0 == "config.json"
            } ?? false
            return hasModelFiles
        }

        return false
    }

    /// Download a model from HuggingFace
    func downloadModel(_ model: Model, progressCallback: ((String) -> Void)? = nil) async throws {
        Self.logger.info("Downloading MLX model: \(model.displayName)")
        progressCallback?("Preparing to download \(model.displayName)...")

        do {
            // MLXLLM's loadModel() automatically downloads if not present
            progressCallback?("Downloading \(model.displayName) (\(model.approximateSize))...")

            _ = try await loadModel(id: model.rawValue)

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

    /// Delete a downloaded model
    func deleteModel(_ model: Model) throws {
        guard let modelPath = getModelPath(for: model) else {
            throw VoiceScribeError.invalidConfiguration(reason: "Cannot find Documents directory")
        }

        if FileManager.default.fileExists(atPath: modelPath.path) {
            try FileManager.default.removeItem(at: modelPath)
            Self.logger.info("Deleted MLX model: \(model.displayName)")
        }
    }

    /// Get list of downloaded models
    static func getDownloadedModels() -> [Model] {
        return Model.allCases.filter { model in
            MLXService.shared.isModelDownloaded(model)
        }
    }

    // MARK: - Post-Processing

    /// Post-process text using local MLX LLM
    /// - Returns: AI-enhanced text
    /// - Throws: VoiceScribeError if MLX is unavailable, model not downloaded, or processing fails
    /// - Note: No fallback to basic cleanup - it's real AI enhancement or error
    func postProcess(text: String) async throws -> String {
        guard isAvailable else {
            throw VoiceScribeError.invalidConfiguration(
                reason: "MLX requires Apple Silicon (M1/M2/M3/M4)"
            )
        }

        let selectedModel = currentModel
        guard isModelDownloaded(selectedModel) else {
            throw VoiceScribeError.modelNotFound(modelName: selectedModel.displayName)
        }

        Self.logger.info("Starting MLX post-processing with model: \(selectedModel.displayName)")
        progressHandler?("Loading LLM model...")

        // Load the model
        Self.logger.info("Loading MLX model: \(selectedModel.rawValue)")
        progressHandler?("Loading \(selectedModel.displayName)...")

        let model = try await loadModel(id: selectedModel.rawValue)

        Self.logger.info("Model loaded successfully")
        progressHandler?("Enhancing transcription...")

        // Create a chat session
        let session = ChatSession(model)

        // Create the prompt for post-processing
        let prompt = """
        Improve this transcription by adding proper punctuation, capitalization, and fixing obvious errors. \
        Return ONLY the cleaned text without any explanations or commentary:

        \(text)
        """

        // Generate the improved text
        Self.logger.info("Generating improved text")
        let improvedText = try await session.respond(to: prompt)

        let trimmed = improvedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            Self.logger.error("MLX returned empty result")
            throw VoiceScribeError.postProcessingFailed(reason: "Model returned empty result")
        }

        Self.logger.info("MLX post-processing successful, generated \(trimmed.count) characters")
        return trimmed
    }

    /// Reload model preference from UserDefaults
    func reloadModelFromPreferences() {
        let model = currentModel
        Self.logger.info("Reloaded MLX model from preferences: \(model.displayName)")
    }
}
