import XCTest
import ComposableArchitecture
@testable import VoiceScribe

@MainActor
final class PipelineFeatureTests: XCTestCase {
    func test_pipeline_withoutCleanup_completesWithOriginalTranscript() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-without-cleanup.m4a")
        let original = TranscriptArtifact(text: "raw transcript", engine: "Whisper", model: "Medium")
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { .whisper(localLLMEnabled: false) }),
                transcriptionClient: .init(transcribe: { _, _, _ in original }),
                cleanupClient: .init(clean: { _, _, _ in nil }),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return false
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Whisper...")
        }

        await store.receive(.transcriptionFinished(original)) {
            $0.inFlightOriginal = original
            $0.latestRun = TranscriptRun(original: original, processed: nil)
            $0.phase = .transcribing("Finalizing transcript...")
        }

        await store.receive(.completionFinished(false)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .completed(text: "raw transcript", pasted: false)
        }

        let calls = await completionRecorder.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].original, original)
        XCTAssertNil(calls[0].processed)
        XCTAssertEqual(calls[0].audioURL, audioURL)
    }

    func test_pipeline_withCleanup_completesWithProcessedTranscript() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-with-cleanup.m4a")
        let original = TranscriptArtifact(text: "hello world", engine: "Parakeet", model: "English v2")
        let processed = TranscriptArtifact(text: "Hello, world.", engine: "Local LLM", model: "Fast — Qwen3 1.7B")
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_100)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { .parakeet(localLLMEnabled: true) }),
                transcriptionClient: .init(transcribe: { _, _, _ in original }),
                cleanupClient: .init(clean: { _, _, _ in processed }),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return true
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Parakeet...")
        }

        await store.receive(.transcriptionFinished(original)) {
            $0.inFlightOriginal = original
            $0.phase = .cleaning("Cleaning transcript...")
        }

        await store.receive(.cleanupFinished(processed)) {
            $0.latestRun = TranscriptRun(original: original, processed: processed)
            $0.phase = .cleaning("Finalizing transcript...")
        }

        await store.receive(.completionFinished(true)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .completed(text: "Hello, world.", pasted: true)
        }

        let calls = await completionRecorder.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].original, original)
        XCTAssertEqual(calls[0].processed, processed)
        XCTAssertEqual(calls[0].audioURL, audioURL)
    }

    func test_pipeline_whisperSelection_usesConfiguredModelAcrossTranscriptionAndCompletion() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-whisper-settings.m4a")
        let settings = PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "whisper",
            whisperModel: .distilLargeV3,
            parakeetModel: .multilingualV3,
            localLLMEnabled: false,
            localLLMModel: .llama3_2_3b,
            smartPasteEnabled: true,
            autoStartRecordingFromShortcut: false,
            historyLimit: 50
        )
        let transcriptionRecorder = TranscriptionInvocationRecorder()
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_150)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { settings }),
                transcriptionClient: .init(
                    transcribe: { _, settings, _ in
                        await transcriptionRecorder.record(settings)
                        return TranscriptArtifact(
                            text: "transcribed text",
                            engine: "Whisper",
                            model: "Balanced — Distil Large v3"
                        )
                    }
                ),
                cleanupClient: .init(clean: { _, _, _ in nil }),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return false
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Whisper...")
        }

        let original = TranscriptArtifact(
            text: "transcribed text",
            engine: "Whisper",
            model: "Balanced — Distil Large v3"
        )

        await store.receive(.transcriptionFinished(original)) {
            $0.inFlightOriginal = original
            $0.latestRun = TranscriptRun(original: original, processed: nil)
            $0.phase = .transcribing("Finalizing transcript...")
        }

        await store.receive(.completionFinished(false)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .completed(text: "transcribed text", pasted: false)
        }

        let transcriptionCalls = await transcriptionRecorder.recordedCalls()
        XCTAssertEqual(transcriptionCalls, [settings])

        let completionCalls = await completionRecorder.recordedCalls()
        XCTAssertEqual(completionCalls.count, 1)
        XCTAssertEqual(completionCalls[0].original.model, "Balanced — Distil Large v3")
        XCTAssertEqual(completionCalls[0].settings, settings)
    }

    func test_pipeline_parakeetAndCleanupSelections_useConfiguredModelsThroughoutRun() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-parakeet-cleanup-settings.m4a")
        let settings = PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "parakeet",
            whisperModel: .small,
            parakeetModel: .multilingualV3,
            localLLMEnabled: true,
            localLLMModel: .qwen3_4b,
            smartPasteEnabled: false,
            autoStartRecordingFromShortcut: false,
            historyLimit: 10
        )
        let transcriptionRecorder = TranscriptionInvocationRecorder()
        let cleanupRecorder = CleanupInvocationRecorder()
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_175)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { settings }),
                transcriptionClient: .init(
                    transcribe: { _, settings, _ in
                        await transcriptionRecorder.record(settings)
                        return TranscriptArtifact(
                            text: "bonjour monde",
                            engine: "Parakeet",
                            model: "Multilingual — Multilingual v3"
                        )
                    }
                ),
                cleanupClient: .init(
                    clean: { original, settings, _ in
                        await cleanupRecorder.record(original: original, settings: settings)
                        return TranscriptArtifact(
                            text: "Bonjour, monde.",
                            engine: "Local LLM",
                            model: "Best — Qwen3 4B"
                        )
                    }
                ),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return false
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Parakeet...")
        }

        let original = TranscriptArtifact(
            text: "bonjour monde",
            engine: "Parakeet",
            model: "Multilingual — Multilingual v3"
        )
        let processed = TranscriptArtifact(
            text: "Bonjour, monde.",
            engine: "Local LLM",
            model: "Best — Qwen3 4B"
        )

        await store.receive(.transcriptionFinished(original)) {
            $0.inFlightOriginal = original
            $0.phase = .cleaning("Cleaning transcript...")
        }

        await store.receive(.cleanupFinished(processed)) {
            $0.latestRun = TranscriptRun(original: original, processed: processed)
            $0.phase = .cleaning("Finalizing transcript...")
        }

        await store.receive(.completionFinished(false)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .completed(text: "Bonjour, monde.", pasted: false)
        }

        let transcriptionCalls = await transcriptionRecorder.recordedCalls()
        XCTAssertEqual(transcriptionCalls, [settings])
        let cleanupCalls = await cleanupRecorder.recordedCalls()
        XCTAssertEqual(cleanupCalls, [.init(original: original, settings: settings)])

        let completionCalls = await completionRecorder.recordedCalls()
        XCTAssertEqual(completionCalls.count, 1)
        XCTAssertEqual(completionCalls[0].original.model, "Multilingual — Multilingual v3")
        XCTAssertEqual(completionCalls[0].processed?.model, "Best — Qwen3 4B")
        XCTAssertEqual(completionCalls[0].settings, settings)
    }

    func test_pipeline_cleanupFallback_completesWithOriginalTranscriptWhenCleanupReturnsNil() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-cleanup-fallback.m4a")
        let original = TranscriptArtifact(text: "needs cleanup", engine: "Whisper", model: "Fast — Small")
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_190)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { .whisper(localLLMEnabled: true) }),
                transcriptionClient: .init(transcribe: { _, _, _ in original }),
                cleanupClient: .init(clean: { _, _, _ in nil }),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return false
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Whisper...")
        }

        await store.receive(.transcriptionFinished(original)) {
            $0.inFlightOriginal = original
            $0.phase = .cleaning("Cleaning transcript...")
        }

        await store.receive(.cleanupFinished(nil)) {
            $0.latestRun = TranscriptRun(original: original, processed: nil)
            $0.phase = .cleaning("Finalizing transcript...")
        }

        await store.receive(.completionFinished(false)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .completed(text: "needs cleanup", pasted: false)
        }

        let calls = await completionRecorder.recordedCalls()
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls[0].original, original)
        XCTAssertNil(calls[0].processed)
    }

    func test_pipeline_ignoredTranscript_returnsToIdleWithoutCompletion() async {
        let audioURL = URL(fileURLWithPath: "/tmp/pipeline-ignored.m4a")
        let completionRecorder = CompletionRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_200)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { audioURL },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                pipelineSettingsClient: .init(load: { .whisper(localLLMEnabled: false) }),
                transcriptionClient: .init(transcribe: { _, _, _ in nil }),
                cleanupClient: .init(clean: { _, _, _ in nil }),
                completionClient: .init(
                    finish: { original, processed, audioURL, settings in
                        await completionRecorder.record(
                            .init(
                                original: original,
                                processed: processed,
                                audioURL: audioURL,
                                settings: settings
                            )
                        )
                        return false
                    }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.stopRecordingTapped) {
            $0.phase = .transcribing("Stopping recording...")
        }

        await store.receive(.recordingStopped(audioURL)) {
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
            $0.inFlightAudioURL = audioURL
            $0.phase = .transcribing("Transcribing with Whisper...")
        }

        await store.receive(.transcriptionFinished(nil)) {
            $0.inFlightAudioURL = nil
            $0.inFlightOriginal = nil
            $0.phase = .idle
        }

        let calls = await completionRecorder.recordedCalls()
        XCTAssertTrue(calls.isEmpty)
    }

    func test_pipeline_permissionDenied_setsError() async {
        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { false },
                    requestPermission: { false },
                    startRecording: {},
                    stopRecording: { URL(fileURLWithPath: "/tmp/unused.m4a") },
                    cancelRecording: {},
                    audioLevel: { 0.0 }
                ),
                autoResetDelay: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingPermissionResponse(false)) {
            $0.phase = .error("Microphone Access Required")
        }
    }

    func test_pipeline_cancelWhileRecording_resetsState() async {
        let cancellationRecorder = CancellationRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_700_000_300)

        let store = TestStore(initialState: PipelineFeature.State()) {
            PipelineFeature(
                recordingClient: .init(
                    hasPermission: { true },
                    requestPermission: { true },
                    startRecording: {},
                    stopRecording: { URL(fileURLWithPath: "/tmp/unused.m4a") },
                    cancelRecording: {
                        await cancellationRecorder.recordCancellation()
                    },
                    audioLevel: { 0.42 }
                ),
                now: { fixedNow },
                autoResetDelay: nil,
                audioMeteringInterval: nil
            )
        }

        await store.send(.startRecordingTapped)
        await store.receive(.recordingStarted) {
            $0.phase = .recording
            $0.recordingStartDate = fixedNow
        }

        await store.send(.cancelTapped) {
            $0.latestRun = nil
            $0.phase = .idle
            $0.recordingStartDate = nil
            $0.audioLevel = 0
            $0.audioLevelHistory = Array(repeating: 0, count: 40)
        }

        let cancellationCount = await cancellationRecorder.count()
        XCTAssertEqual(cancellationCount, 1)
    }
}

private extension PipelineSettingsSnapshot {
    static func whisper(localLLMEnabled: Bool) -> Self {
        PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "whisper",
            whisperModel: .largeV3,
            parakeetModel: .englishV2,
            localLLMEnabled: localLLMEnabled,
            localLLMModel: .qwen3_1_7b,
            smartPasteEnabled: false,
            autoStartRecordingFromShortcut: false,
            historyLimit: 25
        )
    }

    static func parakeet(localLLMEnabled: Bool) -> Self {
        PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "parakeet",
            whisperModel: .largeV3,
            parakeetModel: .englishV2,
            localLLMEnabled: localLLMEnabled,
            localLLMModel: .qwen3_1_7b,
            smartPasteEnabled: false,
            autoStartRecordingFromShortcut: false,
            historyLimit: 25
        )
    }
}

private actor CompletionRecorder {
    struct Call: Equatable {
        let original: TranscriptArtifact
        let processed: TranscriptArtifact?
        let audioURL: URL
        let settings: PipelineSettingsSnapshot
    }

    private(set) var calls: [Call] = []

    func record(_ call: Call) {
        calls.append(call)
    }

    func recordedCalls() -> [Call] {
        calls
    }
}

private actor TranscriptionInvocationRecorder {
    private(set) var calls: [PipelineSettingsSnapshot] = []

    func record(_ settings: PipelineSettingsSnapshot) {
        calls.append(settings)
    }

    func recordedCalls() -> [PipelineSettingsSnapshot] {
        calls
    }
}

private actor CleanupInvocationRecorder {
    struct Call: Equatable {
        let original: TranscriptArtifact
        let settings: PipelineSettingsSnapshot
    }

    private(set) var calls: [Call] = []

    func record(original: TranscriptArtifact, settings: PipelineSettingsSnapshot) {
        calls.append(.init(original: original, settings: settings))
    }

    func recordedCalls() -> [Call] {
        calls
    }
}

private actor CancellationRecorder {
    private(set) var cancellationCount = 0

    func recordCancellation() {
        cancellationCount += 1
    }

    func count() -> Int {
        cancellationCount
    }
}
