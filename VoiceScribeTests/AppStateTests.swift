//
//  AppStateTests.swift
//  VoiceScribeTests
//

import XCTest
@testable import VoiceScribe

@MainActor
final class AppStateTests: XCTestCase {

    // MARK: - Recording Lifecycle

    func test_startRecording_setsStateToRecording() async {
        let audioRecorder = AudioRecordingClientSpy()
        let transcriptionService = TranscriptionServiceStub()

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [transcriptionService],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()

        XCTAssertEqual(appState.recordingState, .recording)
        XCTAssertEqual(audioRecorder.startRecordingCalls, 1)
    }

    func test_startRecording_withError_setsStateToError() async {
        let audioRecorder = AudioRecordingClientSpy(
            startRecordingResult: .failure(TestError(message: TestConstants.recordingFailureMessage))
        )

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()

        XCTAssertEqual(appState.recordingState, .error(TestConstants.recordingFailureMessage))
    }

    func test_cancelRecording_resetsStateToIdle() async {
        let audioRecorder = AudioRecordingClientSpy()

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()
        await appState.cancelRecording()

        XCTAssertEqual(appState.recordingState, .idle)
        XCTAssertEqual(audioRecorder.cancelRecordingCalls, 1)
    }

    func test_stopRecording_withError_setsStateToError() async {
        let audioRecorder = AudioRecordingClientSpy(
            stopRecordingResult: .failure(TestError(message: TestConstants.recordingFailureMessage))
        )

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()
        await appState.stopRecording()

        XCTAssertEqual(appState.recordingState, .error(TestConstants.recordingFailureMessage))
    }

    // MARK: - Transcription Flow

    func test_transcription_success_setsStateToCompleted() async {
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(hasAccessibilityPermission: false),
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(for: .milliseconds(100))

        if case .completed(let text, _, _) = appState.recordingState {
            XCTAssertEqual(text, TestConstants.transcribedText)
        } else {
            XCTFail("Expected completed state, got \(appState.recordingState)")
        }
    }

    func test_transcription_success_copiesToClipboard() async {
        let clipboardSpy = ClipboardClientSpy()
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(hasAccessibilityPermission: false),
            clipboardClient: clipboardSpy
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(clipboardSpy.copiedTexts.last, TestConstants.transcribedText)
    }

    func test_transcription_success_savesToHistory() async {
        let historySpy = HistoryRepositoryFake()
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(hasAccessibilityPermission: false),
            clipboardClient: ClipboardClientSpy(),
            historyRepository: historySpy
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(historySpy.savedEntries.count, 1)
        XCTAssertEqual(historySpy.savedEntries.first?.text, TestConstants.transcribedText)
        XCTAssertEqual(historySpy.savedEntries.first?.serviceIdentifier, TestConstants.serviceIdentifier)
    }

    func test_transcription_failure_setsStateToError() async {
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .failure(TestError(message: TestConstants.transcriptionFailureMessage))
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(hasAccessibilityPermission: false),
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(appState.recordingState, .error(TestConstants.transcriptionFailureMessage))
    }

    func test_transcription_withoutService_setsErrorState() async {
        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(hasAccessibilityPermission: false),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription to complete
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(appState.recordingState, .error(TestConstants.noServiceErrorMessage))
    }

    // MARK: - Smart Paste

    func test_smartPaste_enabled_withPermission_pastesText() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: true)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: true)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = true

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription and paste
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(pasteSpy.simulatePasteCalls.count, 1)
        XCTAssertEqual(focusSpy.restorePreviousApplicationCalls, 1)
    }

    func test_smartPaste_enabled_withoutPermission_skips() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: false)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: true)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = true

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(pasteSpy.simulatePasteCalls.count, 0)
    }

    func test_smartPaste_disabled_skips() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: true)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: true)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = false

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(pasteSpy.simulatePasteCalls.count, 0)
        XCTAssertEqual(focusSpy.restorePreviousApplicationCalls, 0)
    }

    func test_smartPaste_withoutPreviousApp_skips() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: true)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: false)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = true

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(pasteSpy.simulatePasteCalls.count, 0)
    }

    func test_smartPaste_restoreFails_skips() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: true)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: true, restoreResult: false)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = true

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(focusSpy.restorePreviousApplicationCalls, 1)
        XCTAssertEqual(pasteSpy.simulatePasteCalls.count, 0)
    }

    func test_smartPaste_success_setsCompletedWithPastedTrue() async {
        let pasteSpy = PasteClientSpy(hasAccessibilityPermission: true, simulateResult: true)
        let focusSpy = AppFocusClientSpy(hasPreviousApplication: true)
        let transcriptionService = TranscriptionServiceStub(
            transcribeResult: .success(TestConstants.transcribedText)
        )

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [transcriptionService],
            appFocusClient: focusSpy,
            pasteClient: pasteSpy,
            clipboardClient: ClipboardClientSpy()
        )
        appState.selectedServiceIdentifier = TestConstants.serviceIdentifier
        appState.smartPasteEnabled = true

        await appState.startRecording()
        await appState.stopRecording()

        // Wait for transcription and paste
        try? await Task.sleep(for: .milliseconds(500))

        if case .completed(_, let pasted, let attempted) = appState.recordingState {
            XCTAssertTrue(pasted)
            XCTAssertTrue(attempted)
        } else {
            XCTFail("Expected completed state, got \(appState.recordingState)")
        }
    }

    // MARK: - Service Selection

    func test_serviceSelection_updatesCurrentService() async {
        let service1 = TranscriptionServiceStub(identifier: "service1")
        let service2 = TranscriptionServiceStub(identifier: "service2")

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [service1, service2],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        appState.selectedServiceIdentifier = "service1"
        XCTAssertEqual(appState.currentService?.identifier, "service1")

        appState.selectedServiceIdentifier = "service2"
        XCTAssertEqual(appState.currentService?.identifier, "service2")
    }

    func test_serviceSelection_invalidIdentifier_setsNilService() async {
        let service = TranscriptionServiceStub(identifier: "valid")

        let appState = AppState(
            audioRecorder: AudioRecordingClientSpy(),
            services: [service],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        appState.selectedServiceIdentifier = "nonexistent"

        XCTAssertNil(appState.currentService)
    }

    // MARK: - Audio Level Monitoring

    func test_audioLevelMonitoring_startsOnRecording() async {
        let audioRecorder = AudioRecordingClientSpy(audioLevel: TestConstants.testAudioLevel)

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()

        // Wait for audio level monitoring to kick in
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertNotNil(appState.recordingStartDate)
    }

    func test_audioLevelMonitoring_stopsOnCancel() async {
        let audioRecorder = AudioRecordingClientSpy()

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()
        await appState.cancelRecording()

        XCTAssertNil(appState.recordingStartDate)
        XCTAssertEqual(appState.audioLevel, 0.0)
    }

    // MARK: - Cleanup

    func test_cleanup_cancelsRecording() async {
        let audioRecorder = AudioRecordingClientSpy()

        let appState = AppState(
            audioRecorder: audioRecorder,
            services: [TranscriptionServiceStub()],
            appFocusClient: AppFocusClientSpy(),
            pasteClient: PasteClientSpy(),
            clipboardClient: ClipboardClientSpy()
        )

        await appState.startRecording()
        appState.cleanup()

        // Wait for cleanup task
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(audioRecorder.cancelRecordingCalls, 1)
    }
}
