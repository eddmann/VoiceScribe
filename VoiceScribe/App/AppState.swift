import Foundation
import SwiftUI

/// Central application state using modern @Observable macro
@MainActor
@Observable
final class AppState {
    /// Shared instance for global access (used by Settings scene)
    static let shared = AppState()

    // MARK: - Services
    @ObservationIgnored private let audioRecorder: AudioRecordingClient
    @ObservationIgnored private let appFocusClient: AppFocusClient
    @ObservationIgnored private let pasteClient: PasteClient
    @ObservationIgnored private let clipboardClient: ClipboardClient
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var historyRepository: HistoryRepositoryProtocol?
    private(set) var availableServices: [any TranscriptionService]
    var currentService: (any TranscriptionService)? {
        availableServices.first { $0.identifier == settings.selectedServiceIdentifier }
    }

    // MARK: - Recording State
    private(set) var recordingState: RecordingState = .idle {
        didSet {
            guard oldValue != recordingState else { return }
            resetTask?.cancel()
            resetTask = nil
        }
    }
    private(set) var audioLevel: Float = 0.0
    private(set) var audioLevelHistory: [Float] = Array(repeating: 0, count: 40)
    private(set) var recordingStartDate: Date?

    // MARK: - Settings
    var selectedServiceIdentifier: String {
        get { settings.selectedServiceIdentifier }
        set { settings.selectedServiceIdentifier = newValue }
    }

    var smartPasteEnabled: Bool {
        get { settings.smartPasteEnabled }
        set { settings.smartPasteEnabled = newValue }
    }

    var hasAccessibilityPermission: Bool {
        pasteClient.hasAccessibilityPermission
    }

    func openAccessibilitySettings() {
        pasteClient.openAccessibilitySettings()
    }

    // MARK: - Audio Level Timer
    private var audioLevelTask: Task<Void, Never>?
    private var transcriptionTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var activeSessionID: UUID?
    private var activeAudioURL: URL?

    init(
        audioRecorder: AudioRecordingClient = AudioRecorder(),
        services: [any TranscriptionService] = [OpenAIService(), WhisperKitService()],
        appFocusClient: AppFocusClient = AppFocusManager.shared,
        pasteClient: PasteClient = PasteSimulator.shared,
        clipboardClient: ClipboardClient = PasteboardClipboardClient(),
        historyRepository: HistoryRepositoryProtocol? = nil,
        settings: SettingsStore = .shared
    ) {
        self.audioRecorder = audioRecorder
        self.availableServices = services
        self.appFocusClient = appFocusClient
        self.pasteClient = pasteClient
        self.clipboardClient = clipboardClient
        self.historyRepository = historyRepository
        self.settings = settings

        _ = settings.selectedServiceIdentifier
        _ = settings.smartPasteEnabled
    }

    // MARK: - Service Management

    func setHistoryRepository(_ repository: HistoryRepositoryProtocol) {
        historyRepository = repository
    }

    // MARK: - Recording Actions

    func startRecording() async {
        guard !recordingState.isProcessing else {
            return
        }

        guard !recordingState.isRecording else {
            return
        }

        resetTask?.cancel()
        resetTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil
        activeSessionID = UUID()
        activeAudioURL = nil

        if !audioRecorder.hasPermission {
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                setError(
                    VoiceScribeError.microphonePermissionDenied.errorDescription
                        ?? "Microphone Access Required",
                    sessionID: activeSessionID
                )
                return
            }
        }

        do {
            recordingState = .recording
            let _ = try await audioRecorder.startRecording()

            // Start audio level monitoring
            startAudioLevelMonitoring()
        } catch {
            setError(error.localizedDescription, sessionID: activeSessionID)
        }
    }

    func stopRecording() async {
        guard recordingState.isRecording else {
            return
        }

        stopAudioLevelMonitoring()

        do {
            let audioURL = try await audioRecorder.stopRecording()
            activeAudioURL = audioURL
            let sessionID = activeSessionID ?? UUID()
            activeSessionID = sessionID

            transcriptionTask?.cancel()
            transcriptionTask = Task { [weak self] in
                await self?.transcribeAudio(audioURL, sessionID: sessionID)
            }
        } catch {
            setError(error.localizedDescription, sessionID: activeSessionID)
        }
    }

    func cancelRecording() async {
        stopAudioLevelMonitoring()
        await audioRecorder.cancelRecording()
        transcriptionTask?.cancel()
        transcriptionTask = nil
        resetTask?.cancel()
        resetTask = nil
        activeSessionID = nil
        activeAudioURL = nil
        recordingState = .idle
    }

    // MARK: - Transcription

    private func transcribeAudio(_ audioURL: URL, sessionID: UUID) async {
        defer {
            if activeSessionID == sessionID || activeSessionID == nil {
                transcriptionTask = nil
            }
        }

        guard activeSessionID == sessionID else {
            cleanupAudioFile(audioURL)
            return
        }

        guard let service = currentService else {
            setError("No transcription service selected", sessionID: sessionID)
            cleanupAudioFile(audioURL)
            activeAudioURL = nil
            return
        }

        let progressHandler: @Sendable (String) -> Void = { [weak self] progress in
            Task { @MainActor in
                guard let self, self.activeSessionID == sessionID else { return }
                self.recordingState = .processing(progress: progress)
            }
        }

        await service.setProgressHandler(progressHandler)
        await service.reloadModelFromPreferences()

        guard activeSessionID == sessionID else {
            cleanupAudioFile(audioURL)
            return
        }

        recordingState = .processing(progress: "Transcribing with \(service.name)...")

        do {
            let text = try await service.transcribe(audioURL: audioURL)

            guard activeSessionID == sessionID else {
                cleanupAudioFile(audioURL)
                return
            }

            // Copy to clipboard
            clipboardClient.copy(text)

            // Save to history
            await saveToHistory(text: text, service: service, audioURL: audioURL)
            cleanupAudioFile(audioURL)
            if activeSessionID == sessionID {
                activeAudioURL = nil
            }

            guard activeSessionID == sessionID else {
                return
            }

            // Smart paste if enabled and permissions granted
            var wasPasted = false
            var smartPasteAttempted = false
            if smartPasteEnabled {
                smartPasteAttempted = true
                wasPasted = await performSmartPaste()
            }

            guard activeSessionID == sessionID else {
                return
            }

            recordingState = .completed(text: text, pasted: wasPasted, smartPasteAttempted: smartPasteAttempted)

            // Auto-reset after 2 seconds
            scheduleAutoReset(sessionID: sessionID)
        } catch let error as VoiceScribeError {
            guard activeSessionID == sessionID else {
                cleanupAudioFile(audioURL)
                return
            }
            setError(error.errorDescription ?? "Transcription failed", sessionID: sessionID)
            cleanupAudioFile(audioURL)
            activeAudioURL = nil
        } catch {
            guard activeSessionID == sessionID else {
                cleanupAudioFile(audioURL)
                return
            }
            setError(error.localizedDescription, sessionID: sessionID)
            cleanupAudioFile(audioURL)
            activeAudioURL = nil
        }
    }

    // MARK: - Smart Paste

    private func performSmartPaste() async -> Bool {
        // Check if accessibility permission is granted
        guard pasteClient.hasAccessibilityPermission else {
            return false
        }

        // Check if we have a previous app to restore to
        guard appFocusClient.hasPreviousApplication else {
            return false
        }

        // Restore focus to previous app
        guard appFocusClient.restorePreviousApplication() else {
            return false
        }

        // Wait a moment for the app to activate
        try? await Task.sleep(for: .milliseconds(200))

        // Simulate paste
        let success = await pasteClient.simulatePasteWithDelay(delay: 0.1)

        // If paste was successful, close the recording window
        if success {
            closeRecordingWindow()
        }

        return success
    }

    private func closeRecordingWindow() {
        // Post a notification to close the recording window
        NotificationCenter.default.post(name: .closeRecordingWindow, object: nil)
    }

    // MARK: - Processing Cancellation

    func cancelProcessing() async {
        guard recordingState.isProcessing else {
            return
        }

        transcriptionTask?.cancel()
        transcriptionTask = nil
        resetTask?.cancel()
        resetTask = nil
        cleanupAudioFile(activeAudioURL)
        activeAudioURL = nil
        activeSessionID = nil
        recordingState = .idle
    }

    func cancelActiveWork() async {
        if recordingState.isRecording {
            await cancelRecording()
        } else if recordingState.isProcessing {
            await cancelProcessing()
        }
    }

    // MARK: - History Management

    private func saveToHistory(
        text: String,
        service: any TranscriptionService,
        audioURL: URL
    ) async {
        await historyRepository?.saveTranscription(
            text: text,
            serviceIdentifier: service.identifier,
            audioURL: audioURL
        )
    }

    // MARK: - Audio Level Monitoring

    private func startAudioLevelMonitoring() {
        recordingStartDate = Date()
        audioLevelTask = Task { @MainActor in
            while !Task.isCancelled {
                let level = audioRecorder.getAudioLevel()
                audioLevel = level

                // Update history buffer for waveform visualization
                audioLevelHistory.removeFirst()
                audioLevelHistory.append(level)

                // ~30fps for smooth waveform animation
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
        audioLevel = 0.0
        recordingStartDate = nil
        // Reset history to flat line
        audioLevelHistory = Array(repeating: 0, count: 40)
    }

    // MARK: - Cleanup

    func cleanup() {
        stopAudioLevelMonitoring()
        Task {
            await audioRecorder.cancelRecording()
        }
        transcriptionTask?.cancel()
        resetTask?.cancel()
        transcriptionTask = nil
        resetTask = nil
        cleanupAudioFile(activeAudioURL)
        activeSessionID = nil
        activeAudioURL = nil
        AudioRecorder.cleanupOldRecordings()
    }

    private func cleanupAudioFile(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func setError(_ message: String, sessionID: UUID? = nil) {
        if let sessionID, activeSessionID != sessionID {
            return
        }
        recordingState = .error(message)
        scheduleAutoReset(duration: .seconds(6), sessionID: sessionID)
    }

    private func scheduleAutoReset(duration: Duration = .seconds(2), sessionID: UUID? = nil) {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            await MainActor.run {
                guard let self else { return }
                if let sessionID, self.activeSessionID != sessionID {
                    return
                }
                self.recordingState = .idle
                self.activeSessionID = nil
                self.activeAudioURL = nil
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let closeRecordingWindow = Notification.Name("closeRecordingWindow")
}
