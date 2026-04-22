import Foundation
import ComposableArchitecture
import Perception

struct TranscriptRun: Equatable, Sendable {
    var original: TranscriptArtifact
    var processed: TranscriptArtifact?

    var finalText: String {
        processed?.text ?? original.text
    }
}

struct PipelineFeature: Reducer {
    @ObservableState
    struct State: Equatable {
        enum Phase: Equatable {
            case idle
            case recording
            case transcribing(String)
            case cleaning(String)
            case completed(text: String, pasted: Bool)
            case error(String)
        }

        var phase: Phase = .idle
        var audioLevel: Float = 0
        var audioLevelHistory: [Float] = Array(repeating: 0, count: 40)
        var recordingStartDate: Date?
        var latestRun: TranscriptRun?
        var inFlightAudioURL: URL?
        var inFlightOriginal: TranscriptArtifact?

        var isRecording: Bool {
            if case .recording = phase { return true }
            return false
        }

        var isProcessing: Bool {
            switch phase {
            case .transcribing, .cleaning:
                return true
            default:
                return false
            }
        }
    }

    enum Action: Equatable {
        case startRecordingTapped
        case stopRecordingTapped
        case cancelTapped
        case recordingPermissionResponse(Bool)
        case recordingStarted
        case recordingStartFailed(String)
        case recordingStopped(URL)
        case recordingStopFailed(String)
        case transcriptionProgress(String)
        case transcriptionFinished(TranscriptArtifact?)
        case transcriptionFailed(String)
        case cleanupProgress(String)
        case cleanupFinished(TranscriptArtifact?)
        case completionFinished(Bool)
        case autoReset
        case audioLevelUpdated(Float)
    }

    var recordingClient: RecordingClient = .liveValue
    var pipelineSettingsClient: PipelineSettingsClient = .liveValue
    var transcriptionClient: TranscriptionClient = .liveValue
    var cleanupClient: CleanupClient = .liveValue
    var completionClient: CompletionClient = .liveValue
    var clock: any Clock<Duration> = ContinuousClock()
    var now: @Sendable () -> Date = Date.init
    var autoResetDelay: Duration? = .seconds(2)
    var audioMeteringInterval: Duration? = .milliseconds(33)

    enum CancelID {
        static let audioLevel = "pipeline.audioLevel"
        static let completionReset = "pipeline.completionReset"
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startRecordingTapped:
                guard !state.isRecording, !state.isProcessing else { return .none }

                state.phase = .idle
                state.latestRun = nil

                if !recordingClient.hasPermission() {
                    return .run { send in
                        await send(.recordingPermissionResponse(await recordingClient.requestPermission()))
                    }
                }

                return startRecordingEffect()

            case .recordingPermissionResponse(let granted):
                guard granted else {
                    state.phase = .error("Microphone Access Required")
                    return scheduleAutoReset()
                }
                return startRecordingEffect()

            case .recordingStarted:
                state.phase = .recording
                state.recordingStartDate = now()
                guard let audioMeteringInterval else {
                    return .none
                }
                return .run { send in
                    while !Task.isCancelled {
                        try? await clock.sleep(for: audioMeteringInterval)
                        await send(.audioLevelUpdated(await recordingClient.audioLevel()))
                    }
                }
                .cancellable(id: CancelID.audioLevel)

            case .recordingStartFailed(let message):
                state.phase = .error(message)
                return scheduleAutoReset()

            case .stopRecordingTapped:
                guard state.isRecording else { return .none }
                state.phase = .transcribing("Stopping recording...")
                return .merge(
                    .cancel(id: CancelID.audioLevel),
                    .run { send in
                        do {
                            let audioURL = try await recordingClient.stopRecording()
                            await send(.recordingStopped(audioURL))
                        } catch {
                            await send(.recordingStopFailed(error.localizedDescription))
                        }
                    }
                )

            case .recordingStopFailed(let message):
                state.recordingStartDate = nil
                resetAudioLevels(&state)
                state.phase = .error(message)
                return scheduleAutoReset()

            case .recordingStopped(let audioURL):
                state.recordingStartDate = nil
                resetAudioLevels(&state)
                state.inFlightAudioURL = audioURL
                let settings = pipelineSettingsClient.load()
                let engineName = settings.selectedTranscriptionEngine == "parakeet" ? "Parakeet" : "Whisper"
                state.phase = .transcribing("Transcribing with \(engineName)...")

                return .run { send in
                    do {
                        let artifact = try await transcriptionClient.transcribe(
                            audioURL,
                            settings,
                            { progress in
                                Task { await send(.transcriptionProgress(progress)) }
                            }
                        )
                        await send(.transcriptionFinished(artifact))
                    } catch {
                        await send(.transcriptionFailed(error.localizedDescription))
                    }
                }

            case .transcriptionProgress(let progress):
                state.phase = .transcribing(progress)
                return .none

            case .transcriptionFailed(let message):
                state.inFlightAudioURL = nil
                state.inFlightOriginal = nil
                state.phase = .error(message)
                return scheduleAutoReset()

            case .transcriptionFinished(nil):
                state.inFlightAudioURL = nil
                state.inFlightOriginal = nil
                state.phase = .idle
                return .none

            case .transcriptionFinished(let artifact?):
                guard let audioURL = state.inFlightAudioURL else {
                    state.phase = .error("Missing recorded audio")
                    return scheduleAutoReset()
                }

                state.inFlightOriginal = artifact
                let settings = pipelineSettingsClient.load()
                if settings.localLLMEnabled {
                    state.phase = .cleaning("Cleaning transcript...")
                    return .run { send in
                        let processed = await cleanupClient.clean(
                            artifact,
                            settings,
                            { progress in
                                Task { await send(.cleanupProgress(progress)) }
                            }
                        )
                        await send(.cleanupFinished(processed))
                    }
                } else {
                    let run = TranscriptRun(original: artifact, processed: nil)
                    state.latestRun = run
                    state.phase = .transcribing("Finalizing transcript...")
                    return .run { send in
                        let pasted = await completionClient.finish(artifact, nil, audioURL, settings)
                        await send(.completionFinished(pasted))
                    }
                }

            case .cleanupProgress(let progress):
                state.phase = .cleaning(progress)
                return .none

            case .cleanupFinished(let processed):
                guard let original = state.inFlightOriginal,
                      let audioURL = state.inFlightAudioURL else {
                    state.phase = .error("Missing transcript context")
                    return scheduleAutoReset()
                }

                let settings = pipelineSettingsClient.load()
                let run = TranscriptRun(original: original, processed: processed)
                state.latestRun = run
                state.phase = .cleaning("Finalizing transcript...")
                return .run { send in
                    let pasted = await completionClient.finish(original, processed, audioURL, settings)
                    await send(.completionFinished(pasted))
                }

            case .completionFinished(let pasted):
                guard let run = state.latestRun else {
                    state.phase = .idle
                    return .none
                }

                state.inFlightAudioURL = nil
                state.inFlightOriginal = nil
                state.phase = .completed(text: run.finalText, pasted: pasted)
                return scheduleAutoReset()

            case .cancelTapped:
                state.inFlightAudioURL = nil
                state.inFlightOriginal = nil
                state.latestRun = nil
                state.phase = .idle
                state.recordingStartDate = nil
                resetAudioLevels(&state)
                return .merge(
                    .cancel(id: CancelID.audioLevel),
                    .cancel(id: CancelID.completionReset),
                    .run { _ in
                        await recordingClient.cancelRecording()
                    }
                )

            case .audioLevelUpdated(let level):
                guard state.isRecording else { return .none }
                state.audioLevel = level
                state.audioLevelHistory.removeFirst()
                state.audioLevelHistory.append(level)
                return .none

            case .autoReset:
                guard !state.isRecording, !state.isProcessing else { return .none }
                state.phase = .idle
                return .none
            }
        }
    }

    private func startRecordingEffect() -> Effect<Action> {
        .run { send in
            do {
                try await recordingClient.startRecording()
                await send(.recordingStarted)
            } catch {
                await send(.recordingStartFailed(error.localizedDescription))
            }
        }
    }

    private func scheduleAutoReset() -> Effect<Action> {
        guard let autoResetDelay else {
            return .none
        }

        return .run { send in
            try await clock.sleep(for: autoResetDelay)
            await send(.autoReset)
        }
        .cancellable(id: CancelID.completionReset, cancelInFlight: true)
    }

    private func resetAudioLevels(_ state: inout State) {
        state.audioLevel = 0
        state.audioLevelHistory = Array(repeating: 0, count: 40)
    }
}
