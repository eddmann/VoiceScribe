import Foundation
import os.log
import MLX
import MLXRandom
import MLXLLM
import MLXLMCommon

/// Local LLM cleanup engine backed by MLX models.
actor LocalLLMCleanupEngine: CleanupEngine {
    nonisolated private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "LocalLLMCleanupEngine"
    )
    @MainActor static let shared = LocalLLMCleanupEngine()
    nonisolated let name = "Local LLM"

    /// Available MLX models for transcript cleanup
    enum Model: String, CaseIterable {
        case qwen3_1_7b = "Qwen/Qwen3-1.7B-MLX-4bit"
        case llama3_2_3b = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case qwen3_4b = "Qwen/Qwen3-4B-MLX-4bit"

        var displayName: String {
            switch self {
            case .qwen3_1_7b:
                return "Fast — Qwen3 1.7B"
            case .llama3_2_3b:
                return "Balanced — Llama 3.2 3B"
            case .qwen3_4b:
                return "Best — Qwen3 4B"
            }
        }

        var description: String {
            switch self {
            case .qwen3_1_7b:
                return "Newest small MLX option for fast punctuation, formatting, and light cleanup."
            case .llama3_2_3b:
                return "Balanced MLX cleanup model with strong instruction-following and stable output."
            case .qwen3_4b:
                return "Largest MLX option here for the best local cleanup quality."
            }
        }

        var approximateSize: String {
            switch self {
            case .qwen3_1_7b:
                return "~1.2 GB"
            case .llama3_2_3b:
                return "~1.8 GB"
            case .qwen3_4b:
                return "~2.6 GB"
            }
        }

        var technicalModelName: String {
            rawValue
        }

        var huggingFaceURL: URL {
            URL(string: "https://huggingface.co/\(rawValue)")!
        }
    }

    nonisolated private var currentModel: Model {
        if let savedModel = UserDefaults.standard.string(forKey: SettingsKeys.localLLMModel),
           let model = Model(rawValue: savedModel) {
            return model
        }
        return .qwen3_1_7b
    }

    /// Get the currently selected model
    nonisolated func getCurrentModel() -> Model {
        return currentModel
    }

    func currentModelName() -> String {
        currentModel.displayName
    }

    private var progressHandler: (@Sendable (String) -> Void)?
    private var cachedModel: ModelContainer?
    private var cachedModelIdentifier: String?

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

    func isReady() -> Bool {
        let selectedModel = currentModel
        return isAvailable && isModelDownloaded(selectedModel)
    }

    /// Download a model from HuggingFace
    func downloadModel(_ model: Model, progressCallback: ((String) -> Void)? = nil) async throws {
        Self.logger.info("Downloading MLX model: \(model.displayName)")
        progressCallback?("Preparing \(model.displayName) Local LLM model...")

        do {
            // MLXLLM's loadModel() automatically downloads if not present
            progressCallback?("Downloading \(model.displayName) model (\(model.approximateSize))...")

            let loadedModel = try await loadModelContainer(id: model.rawValue)
            cachedModel = loadedModel
            cachedModelIdentifier = model.rawValue

            progressCallback?("Model downloaded! Loading \(model.displayName)...")
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
            LocalLLMCleanupEngine.shared.isModelDownloaded(model)
        }
    }

    // MARK: - Cleanup

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

        Self.logger.info("Starting transcript cleanup with model: \(selectedModel.displayName)")
        progressHandler?("Loading \(selectedModel.displayName) model...")
        let model = try await loadCachedModel(for: selectedModel)

        Self.logger.info("Model loaded successfully")
        progressHandler?("Cleaning transcript with Local LLM...")

        // Create a chat session
        let session = ChatSession(model)

        // Create the prompt for transcript cleanup
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
            throw VoiceScribeError.cleanupFailed(reason: "Model returned empty result")
        }

        Self.logger.info("Transcript cleanup successful, generated \(trimmed.count) characters")
        return trimmed
    }

    /// Reload model preference from UserDefaults
    func reloadModelFromPreferences() {
        let model = currentModel
        if cachedModelIdentifier != model.rawValue {
            cachedModel = nil
            cachedModelIdentifier = nil
        }
        Self.logger.info("Reloaded MLX model from preferences: \(model.displayName)")
    }

    private func loadCachedModel(for model: Model) async throws -> ModelContainer {
        if let cachedModel, cachedModelIdentifier == model.rawValue {
            Self.logger.info("Reusing cached MLX model: \(model.displayName)")
            return cachedModel
        }

        Self.logger.info("Loading MLX model: \(model.rawValue)")
        progressHandler?("Loading \(model.displayName)...")

        let loadedModel = try await loadModelContainer(id: model.rawValue)
        cachedModel = loadedModel
        cachedModelIdentifier = model.rawValue
        return loadedModel
    }
}
