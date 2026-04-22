import Foundation

struct PipelineSettingsSnapshot: Equatable, Sendable {
    var selectedTranscriptionEngine: String
    var whisperModel: WhisperEngine.Model
    var parakeetModel: ParakeetEngine.Model
    var localLLMEnabled: Bool
    var localLLMModel: LocalLLMCleanupEngine.Model
    var smartPasteEnabled: Bool
    var autoStartRecordingFromShortcut: Bool
    var historyLimit: Int

    nonisolated static func == (lhs: PipelineSettingsSnapshot, rhs: PipelineSettingsSnapshot) -> Bool {
        lhs.selectedTranscriptionEngine == rhs.selectedTranscriptionEngine &&
        lhs.whisperModel == rhs.whisperModel &&
        lhs.parakeetModel == rhs.parakeetModel &&
        lhs.localLLMEnabled == rhs.localLLMEnabled &&
        lhs.localLLMModel == rhs.localLLMModel &&
        lhs.smartPasteEnabled == rhs.smartPasteEnabled &&
        lhs.autoStartRecordingFromShortcut == rhs.autoStartRecordingFromShortcut &&
        lhs.historyLimit == rhs.historyLimit
    }
}

struct PipelineSettingsClient: Sendable {
    var load: @Sendable () -> PipelineSettingsSnapshot
}

extension PipelineSettingsClient {
    static let liveValue = PipelineSettingsClient(
        load: {
            let userDefaults = UserDefaults.standard
            let selectedTranscriptionEngine = userDefaults.string(forKey: SettingsKeys.selectedTranscriptionEngine)
                ?? "whisper"
            let whisperModel = WhisperEngine.Model(
                rawValue: userDefaults.string(forKey: SettingsKeys.whisperModel) ?? ""
            ) ?? .small
            let parakeetModel = ParakeetEngine.Model(
                rawValue: userDefaults.string(forKey: SettingsKeys.parakeetModel) ?? ""
            ) ?? .englishV2
            let localLLMModel = LocalLLMCleanupEngine.Model(
                rawValue: userDefaults.string(forKey: SettingsKeys.localLLMModel) ?? ""
            ) ?? .qwen3_1_7b
            let historyLimit = max(1, userDefaults.integer(forKey: SettingsKeys.historyLimit))

            return PipelineSettingsSnapshot(
                selectedTranscriptionEngine: selectedTranscriptionEngine,
                whisperModel: whisperModel,
                parakeetModel: parakeetModel,
                localLLMEnabled: userDefaults.bool(forKey: SettingsKeys.localLLMEnabled),
                localLLMModel: localLLMModel,
                smartPasteEnabled: userDefaults.bool(forKey: SettingsKeys.smartPasteEnabled),
                autoStartRecordingFromShortcut: userDefaults.bool(
                    forKey: SettingsKeys.autoStartRecordingFromShortcut
                ),
                historyLimit: historyLimit
            )
        }
    )

    static let testValue = PipelineSettingsClient(
        load: {
            PipelineSettingsSnapshot(
                selectedTranscriptionEngine: "whisper",
                whisperModel: .small,
                parakeetModel: .englishV2,
                localLLMEnabled: false,
                localLLMModel: .qwen3_1_7b,
                smartPasteEnabled: false,
                autoStartRecordingFromShortcut: false,
                historyLimit: 25
            )
        }
    )
}

struct RecordingClient: Sendable {
    var hasPermission: @Sendable () -> Bool
    var requestPermission: @Sendable () async -> Bool
    var startRecording: @Sendable () async throws -> Void
    var stopRecording: @Sendable () async throws -> URL
    var cancelRecording: @Sendable () async -> Void
    var audioLevel: @Sendable () async -> Float
}

extension RecordingClient {
    static let liveValue: RecordingClient = {
        let recorder = AudioRecorder()
        return RecordingClient(
            hasPermission: { true },
            requestPermission: { await recorder.requestPermission() },
            startRecording: {
                _ = try await recorder.startRecording()
            },
            stopRecording: {
                try await recorder.stopRecording()
            },
            cancelRecording: {
                await recorder.cancelRecording()
            },
            audioLevel: {
                await MainActor.run {
                    recorder.getAudioLevel()
                }
            }
        )
    }()

    static let testValue = RecordingClient(
        hasPermission: { true },
        requestPermission: { true },
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test-audio.m4a") },
        cancelRecording: {},
        audioLevel: { 0.0 }
    )
}

struct TranscriptionClient: Sendable {
    var transcribe: @Sendable (
        _ audioURL: URL,
        _ settings: PipelineSettingsSnapshot,
        _ progress: @escaping @Sendable (String) -> Void
    ) async throws -> TranscriptArtifact?
}

extension TranscriptionClient {
    @MainActor
    private static let sharedWhisperEngine = WhisperEngine()

    @MainActor
    private static let sharedParakeetEngine = ParakeetEngine()

    static let liveValue = TranscriptionClient(
        transcribe: { audioURL, settings, progress in
            let engine: any TranscriptionEngine
            let engineName: String
            let modelName: String

            switch settings.selectedTranscriptionEngine {
            case "parakeet":
                engine = await MainActor.run {
                    sharedParakeetEngine
                }
                engineName = "Parakeet"
                modelName = settings.parakeetModel.displayName
            default:
                engine = await MainActor.run {
                    sharedWhisperEngine
                }
                engineName = "Whisper"
                modelName = settings.whisperModel.displayName
            }

            await engine.setProgressHandler(progress)
            await engine.reloadModelFromPreferences()

            let result = try await engine.transcribe(audioURL: audioURL)
            guard case .success(let text) = result.outcome else {
                return nil
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }

            return TranscriptArtifact(text: trimmed, engine: engineName, model: modelName)
        }
    )

    static let testValue = TranscriptionClient(
        transcribe: { _, _, _ in
            TranscriptArtifact(text: "Stub transcript", engine: "Whisper", model: "Fast — Small")
        }
    )
}

struct CleanupClient: Sendable {
    var clean: @Sendable (
        _ original: TranscriptArtifact,
        _ settings: PipelineSettingsSnapshot,
        _ progress: @escaping @Sendable (String) -> Void
    ) async -> TranscriptArtifact?
}

extension CleanupClient {
    static let liveValue = CleanupClient(
        clean: { original, settings, progress in
            guard settings.localLLMEnabled else {
                return nil
            }

            let cleanupEngine = await MainActor.run {
                LocalLLMCleanupEngine.shared
            }
            await cleanupEngine.setProgressHandler(progress)
            await cleanupEngine.reloadModelFromPreferences()

            guard cleanupEngine.isAvailable else {
                return nil
            }

            let selectedModel = cleanupEngine.getCurrentModel()

            if !(await cleanupEngine.isReady()) {
                do {
                    try await cleanupEngine.downloadModel(selectedModel, progressCallback: progress)
                } catch {
                    return nil
                }
            }

            do {
                let processedText = try await cleanupEngine.postProcess(text: original.text)
                let trimmed = processedText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    return nil
                }

                return TranscriptArtifact(
                    text: trimmed,
                    engine: cleanupEngine.name,
                    model: await cleanupEngine.currentModelName()
                )
            } catch {
                return nil
            }
        }
    )

    static let testValue = CleanupClient(
        clean: { _, _, _ in nil }
    )
}

struct CompletionClient: Sendable {
    var finish: @Sendable (
        _ original: TranscriptArtifact,
        _ processed: TranscriptArtifact?,
        _ audioURL: URL,
        _ settings: PipelineSettingsSnapshot
    ) async -> Bool
}

extension CompletionClient {
    static let liveValue = CompletionClient(
        finish: { _, _, _, _ in false }
    )

    static let testValue = CompletionClient(
        finish: { _, _, _, _ in false }
    )
}
