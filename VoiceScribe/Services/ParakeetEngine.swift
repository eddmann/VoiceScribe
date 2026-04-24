import Foundation
@preconcurrency import FluidAudio
import os.log

/// Local Parakeet transcription powered by FluidAudio CoreML models.
actor ParakeetEngine: TranscriptionEngine {
    nonisolated private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "ParakeetEngine"
    )

    nonisolated private static let minimumAcceptedConfidence = 0.12

    let name = "Parakeet"
    let identifier = "parakeet"

    private var asrManager: AsrManager?
    private var loadedModel: Model?
    private var progressHandler: (@Sendable (String) -> Void)?

    enum Model: String, CaseIterable, Codable {
        case englishV2 = "fluid_parakeet_tdt_v2"
        case multilingualV3 = "fluid_parakeet_tdt_v3"

        var displayName: String {
            switch self {
            case .englishV2:
                return "English — English v2"
            case .multilingualV3:
                return "Multilingual — Multilingual v3"
            }
        }

        var description: String {
            switch self {
            case .englishV2:
                return "Best English-only Parakeet model for dictation quality and recall."
            case .multilingualV3:
                return "Parakeet model for 25 European languages with strong English support."
            }
        }

        var technicalModelName: String {
            switch self {
            case .englishV2:
                return "FluidInference/parakeet-tdt-0.6b-v2-coreml"
            case .multilingualV3:
                return "FluidInference/parakeet-tdt-0.6b-v3-coreml"
            }
        }

        var approximateSize: String {
            switch self {
            case .englishV2:
                return "~2.4 GB"
            case .multilingualV3:
                return "~2.6 GB"
            }
        }

        var asrVersion: AsrModelVersion {
            switch self {
            case .englishV2:
                return .v2
            case .multilingualV3:
                return .v3
            }
        }

        var defaultLanguageCode: String? {
            switch self {
            case .englishV2:
                return "en"
            case .multilingualV3:
                return nil
            }
        }

        var huggingFaceURL: URL {
            switch self {
            case .englishV2:
                return URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml")!
            case .multilingualV3:
                return URL(string: "https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v3-coreml")!
            }
        }
    }

    private var selectedModel: Model {
        if let rawValue = UserDefaults.standard.string(forKey: SettingsKeys.parakeetModel),
           let model = Model(rawValue: rawValue) {
            return model
        }
        return .englishV2
    }

    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async {
        progressHandler = handler
    }

    func reloadModelFromPreferences() async {
        let selectedModel = selectedModel
        if loadedModel != selectedModel {
            if let asrManager {
                await asrManager.cleanup()
                self.asrManager = nil
            }
            loadedModel = nil
        }

        Self.logger.info("Reloaded Parakeet model from preferences: \(selectedModel.rawValue)")
    }

    func currentModelName() async -> String {
        selectedModel.displayName
    }

    var isAvailable: Bool {
        get async {
            SystemInfo.isAppleSilicon
        }
    }

    func validateConfiguration() async throws {
        guard SystemInfo.isAppleSilicon else {
            throw VoiceScribeError.engineNotAvailable(engine: name)
        }
    }

    func transcribe(audioURL: URL) async throws -> TranscriptionResult {
        try await validateConfiguration()

        let selectedModel = selectedModel
        progressHandler?("Preparing \(selectedModel.displayName) Parakeet...")

        let manager = try await ensureManager(for: selectedModel)

        progressHandler?("Running Parakeet locally...")

        do {
            var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            let result = try await manager.transcribe(audioURL, decoderState: &decoderState)
            return normalizeResult(result, model: selectedModel)
        } catch let error as ASRError {
            if case .invalidAudioData = error {
                return .ignored(.noSpeechDetected)
            }

            throw VoiceScribeError.transcriptionFailed(
                engine: name,
                reason: error.localizedDescription
            )
        } catch {
            throw VoiceScribeError.transcriptionFailed(
                engine: name,
                reason: error.localizedDescription
            )
        }
    }

    nonisolated static func getDownloadedModels() -> [Model] {
        Model.allCases.filter(isModelDownloaded)
    }

    nonisolated static func isModelDownloaded(_ model: Model) -> Bool {
        let directory = AsrModels.defaultCacheDirectory(for: model.asrVersion)
        return AsrModels.modelsExist(at: directory, version: model.asrVersion)
    }

    nonisolated static func modelStoragePath(for model: Model) -> String {
        AsrModels.defaultCacheDirectory(for: model.asrVersion).path
    }

    nonisolated static func downloadModel(
        _ model: Model,
        progressHandler: @escaping @Sendable (String) -> Void = { _ in }
    ) async throws {
        guard SystemInfo.isAppleSilicon else {
            throw VoiceScribeError.engineNotAvailable(engine: "Parakeet")
        }

        _ = try await AsrModels.download(
            version: model.asrVersion,
            progressHandler: { progress in
                progressHandler(formatProgress(progress, model: model))
            }
        )
    }

    nonisolated static func deleteModel(_ model: Model) throws {
        let directory = AsrModels.defaultCacheDirectory(for: model.asrVersion)
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }

    private func ensureManager(for model: Model) async throws -> AsrManager {
        if let asrManager, loadedModel == model {
            return asrManager
        }

        let models = try await loadModels(for: model)
        let manager = AsrManager(config: .default)
        try await manager.loadModels(models)
        asrManager = manager
        loadedModel = model
        return manager
    }

    private func loadModels(for model: Model) async throws -> AsrModels {
        let progressReporter = progressHandler
        let configuration = AsrModels.defaultConfiguration()

        do {
            if Self.isModelDownloaded(model) {
                progressReporter?("Loading \(model.displayName) from disk...")
                return try await AsrModels.loadFromCache(
                    configuration: configuration,
                    version: model.asrVersion,
                    progressHandler: { progress in
                        progressReporter?(Self.formatProgress(progress, model: model))
                    }
                )
            }

            progressReporter?("Downloading \(model.displayName) (\(model.approximateSize))...")
            return try await AsrModels.downloadAndLoad(
                configuration: configuration,
                version: model.asrVersion,
                progressHandler: { progress in
                    progressReporter?(Self.formatProgress(progress, model: model))
                }
            )
        } catch {
            Self.logger.error("Parakeet model load failed for \(model.rawValue): \(error.localizedDescription)")

            if Self.isModelDownloaded(model) {
                try? Self.deleteModel(model)
                progressReporter?("Refreshing \(model.displayName) model...")
                return try await AsrModels.downloadAndLoad(
                    configuration: configuration,
                    version: model.asrVersion,
                    progressHandler: { progress in
                        progressReporter?(Self.formatProgress(progress, model: model))
                    }
                )
            }

            throw mapModelError(error, model: model)
        }
    }

    private func normalizeResult(_ result: ASRResult, model: Model) -> TranscriptionResult {
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let averageConfidence = Double(result.confidence)
        let segments = buildSegments(from: result, text: text)

        guard !text.isEmpty else {
            return .ignored(
                .noSpeechDetected,
                segments: segments,
                language: model.defaultLanguageCode,
                averageConfidence: averageConfidence
            )
        }

        if averageConfidence < Self.minimumAcceptedConfidence {
            Self.logger.info(
                "Ignoring low-confidence Parakeet result (\(averageConfidence, format: .fixed(precision: 3)))"
            )
            return .ignored(
                .noSpeechDetected,
                segments: segments,
                language: model.defaultLanguageCode,
                averageConfidence: averageConfidence
            )
        }

        return .success(
            text,
            segments: segments,
            language: model.defaultLanguageCode,
            averageConfidence: averageConfidence
        )
    }

    private func buildSegments(from result: ASRResult, text: String) -> [TranscriptionResult.Segment] {
        guard !text.isEmpty else { return [] }

        if let timings = result.tokenTimings,
           let first = timings.first,
           let last = timings.last {
            return [
                TranscriptionResult.Segment(
                    text: text,
                    startTime: first.startTime,
                    endTime: last.endTime,
                    confidence: Double(result.confidence)
                )
            ]
        }

        return [
            TranscriptionResult.Segment(
                text: text,
                startTime: 0,
                endTime: result.duration,
                confidence: Double(result.confidence)
            )
        ]
    }

    private func mapModelError(_ error: Error, model: Model) -> VoiceScribeError {
        if let error = error as? AsrModelsError {
            switch error {
            case .downloadFailed(let reason):
                return .modelDownloadFailed(modelName: model.displayName, reason: reason)
            case .loadingFailed(let reason), .modelCompilationFailed(let reason):
                return .transcriptionFailed(engine: name, reason: reason)
            case .modelNotFound:
                return .modelNotFound(modelName: model.displayName)
            }
        }

        if let error = error as? ASRError {
            return .transcriptionFailed(engine: name, reason: error.localizedDescription)
        }

        return .transcriptionFailed(engine: name, reason: error.localizedDescription)
    }

    nonisolated private static func formatProgress(
        _ progress: DownloadUtils.DownloadProgress,
        model: Model
    ) -> String {
        let percentage = Int((progress.fractionCompleted * 100).rounded())

        switch progress.phase {
        case .listing:
            return "Checking \(model.displayName) files..."
        case .downloading(let completedFiles, let totalFiles):
            return "Downloading \(model.displayName) (\(completedFiles)/\(totalFiles), \(percentage)%)..."
        case .compiling(let modelName):
            return "Compiling \(modelName) (\(percentage)%)..."
        }
    }
}
