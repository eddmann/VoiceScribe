import Foundation
import SwiftUI
import SwiftData

/// Central application state using modern @Observable macro
@MainActor
@Observable
final class AppState {
    // MARK: - Services
    let audioRecorder = AudioRecorder()
    private(set) var availableServices: [any TranscriptionService] = []
    private(set) var currentService: (any TranscriptionService)?

    // MARK: - Recording State
    private(set) var recordingState: RecordingState = .idle
    private(set) var audioLevel: Float = 0.0

    // MARK: - Settings
    var selectedServiceIdentifier: String {
        didSet {
            UserDefaults.standard.set(selectedServiceIdentifier, forKey: "selectedService")
            updateCurrentService()
        }
    }

    var smartPasteEnabled: Bool {
        didSet {
            UserDefaults.standard.set(smartPasteEnabled, forKey: "smartPasteEnabled")
        }
    }

    // MARK: - History
    var modelContext: ModelContext?

    // MARK: - Audio Level Timer
    private var audioLevelTask: Task<Void, Never>?

    init() {
        // Load saved service preference or default to WhisperKit (local/offline)
        self.selectedServiceIdentifier = UserDefaults.standard.string(
            forKey: "selectedService"
        ) ?? "whisperkit"

        // Load smart paste preference (enabled by default)
        self.smartPasteEnabled = UserDefaults.standard.bool(forKey: "smartPasteEnabled")
        if UserDefaults.standard.object(forKey: "smartPasteEnabled") == nil {
            // First launch - default to enabled
            self.smartPasteEnabled = true
            UserDefaults.standard.set(true, forKey: "smartPasteEnabled")
        }

        // Initialize services
        Task {
            await setupServices()
        }
    }

    // MARK: - Service Management

    private func setupServices() async {
        availableServices = [
            OpenAIService(),
            WhisperKitService()
        ]
        updateCurrentService()
    }

    private func updateCurrentService() {
        currentService = availableServices.first {
            $0.identifier == selectedServiceIdentifier
        }
    }

    // MARK: - Recording Actions

    func startRecording() async {
        do {
            recordingState = .recording
            let _ = try await audioRecorder.startRecording()

            // Start audio level monitoring
            startAudioLevelMonitoring()
        } catch {
            recordingState = .error(error.localizedDescription)
        }
    }

    func stopRecording() async {
        stopAudioLevelMonitoring()

        do {
            let audioURL = try await audioRecorder.stopRecording()
            await transcribeAudio(audioURL)
        } catch {
            recordingState = .error(error.localizedDescription)
        }
    }

    func cancelRecording() async {
        stopAudioLevelMonitoring()
        await audioRecorder.cancelRecording()
        recordingState = .idle
    }

    // MARK: - Transcription

    private func transcribeAudio(_ audioURL: URL) async {
        guard let service = currentService else {
            recordingState = .error("No transcription service selected")
            return
        }

        // Set up progress callback for WhisperKit downloads and reload preferences
        if let whisperKit = service as? WhisperKitService {
            // Reload model from preferences in case it changed
            whisperKit.reloadModelFromPreferences()

            whisperKit.progressCallback = { [weak self] progress in
                self?.recordingState = .processing(progress: progress)
            }
        }

        recordingState = .processing(progress: "Transcribing with \(service.name)...")

        do {
            let text = try await service.transcribe(audioURL: audioURL)

            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            // Save to history
            await saveToHistory(text: text, service: service, audioURL: audioURL)

            recordingState = .completed(text: text)

            // Smart paste if enabled and permissions granted
            if smartPasteEnabled {
                await performSmartPaste()
            }

            // Auto-reset after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                recordingState = .idle
            }
        } catch let error as VoiceScribeError {
            recordingState = .error(error.errorDescription ?? "Transcription failed")
        } catch {
            recordingState = .error(error.localizedDescription)
        }
    }

    // MARK: - Smart Paste

    private func performSmartPaste() async {
        let focusManager = AppFocusManager.shared
        let pasteSimulator = PasteSimulator.shared

        // Check if we have a previous app to restore to
        guard focusManager.hasPreviousApplication else {
            return
        }

        // Restore focus to previous app
        guard focusManager.restorePreviousApplication() else {
            return
        }

        // Wait a moment for the app to activate
        try? await Task.sleep(for: .milliseconds(200))

        // Simulate paste
        _ = await pasteSimulator.simulatePasteWithDelay(delay: 0.1)
    }

    // MARK: - History Management

    private func saveToHistory(
        text: String,
        service: any TranscriptionService,
        audioURL: URL
    ) async {
        guard let context = modelContext else { return }

        // Get audio duration
        let duration = await getAudioDuration(audioURL)

        let record = TranscriptionRecord(
            text: text,
            serviceUsed: service.identifier,
            audioDuration: duration
        )

        context.insert(record)

        do {
            try context.save()
        } catch {
            print("Failed to save transcription: \(error)")
        }

        // Clean up temporary audio file
        try? FileManager.default.removeItem(at: audioURL)
    }

    private func getAudioDuration(_ url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }

    // MARK: - Audio Level Monitoring

    private func startAudioLevelMonitoring() {
        audioLevelTask = Task { @MainActor in
            while !Task.isCancelled {
                audioLevel = audioRecorder.getAudioLevel()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func stopAudioLevelMonitoring() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
        audioLevel = 0.0
    }

    // MARK: - Cleanup

    func cleanup() {
        stopAudioLevelMonitoring()
        Task {
            await audioRecorder.cancelRecording()
        }
        AudioRecorder.cleanupOldRecordings()
    }
}

// MARK: - AVFoundation Import
import AVFoundation
