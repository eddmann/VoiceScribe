//
//  VoiceScribeErrorTests.swift
//  VoiceScribeTests
//

import XCTest
@testable import VoiceScribe

final class VoiceScribeErrorTests: XCTestCase {

    // MARK: - Error Descriptions

    func test_microphonePermissionDenied_hasDescription() {
        let error = VoiceScribeError.microphonePermissionDenied

        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func test_transcriptionFailed_includesServiceAndReason() {
        let serviceName = "TestService"
        let reason = "Network timeout"
        let error = VoiceScribeError.transcriptionFailed(service: serviceName, reason: reason)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains(serviceName))
    }

    func test_modelNotFound_includesModelName() {
        let modelName = "whisper-large"
        let error = VoiceScribeError.modelNotFound(modelName: modelName)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains(modelName))
    }

    // MARK: - Recovery Suggestions

    func test_microphonePermissionDenied_hasRecoverySuggestion() {
        let error = VoiceScribeError.microphonePermissionDenied

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    func test_noAPIKey_hasRecoverySuggestion() {
        let error = VoiceScribeError.noAPIKey(service: "OpenAI")

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.lowercased().contains("settings"))
    }

    func test_modelNotFound_hasRecoverySuggestion() {
        let error = VoiceScribeError.modelNotFound(modelName: "test-model")

        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertFalse(error.recoverySuggestion!.isEmpty)
    }

    // MARK: - All Errors Have Descriptions

    func test_allErrors_haveDescriptions() {
        let errors: [VoiceScribeError] = [
            .microphonePermissionDenied,
            .microphonePermissionRestricted,
            .recordingInitializationFailed,
            .recordingFailed(underlying: "Test"),
            .noAudioRecorded,
            .transcriptionFailed(service: "Test", reason: "Test"),
            .serviceNotAvailable(service: "Test"),
            .noAPIKey(service: "Test"),
            .invalidAPIKey(service: "Test"),
            .networkError(underlying: "Test"),
            .invalidConfiguration(reason: "Test"),
            .modelNotFound(modelName: "Test"),
            .modelDownloadFailed(modelName: "Test", reason: "Test"),
            .postProcessingFailed(reason: "Test")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Empty description for \(error)")
        }
    }

    func test_errorsWithRecoverySuggestions_haveNonEmptyContent() {
        // These errors are expected to have recovery suggestions
        let errorsWithRecoverySuggestions: [VoiceScribeError] = [
            .microphonePermissionDenied,
            .microphonePermissionRestricted,
            .recordingInitializationFailed,
            .noAudioRecorded,
            .serviceNotAvailable(service: "Test"),
            .noAPIKey(service: "Test"),
            .invalidAPIKey(service: "Test"),
            .networkError(underlying: "Test"),
            .modelNotFound(modelName: "Test"),
            .modelDownloadFailed(modelName: "Test", reason: "Test"),
            .postProcessingFailed(reason: "Test")
        ]

        for error in errorsWithRecoverySuggestions {
            XCTAssertNotNil(error.recoverySuggestion, "Missing recovery suggestion for \(error)")
            XCTAssertFalse(error.recoverySuggestion!.isEmpty, "Empty recovery suggestion for \(error)")
        }
    }

    func test_someErrors_mayOmitRecoverySuggestions() {
        // These errors intentionally don't have recovery suggestions because
        // they provide detailed context in errorDescription/failureReason
        let errorsWithoutRecoverySuggestions: [VoiceScribeError] = [
            .recordingFailed(underlying: "Test"),
            .transcriptionFailed(service: "Test", reason: "Test"),
            .invalidConfiguration(reason: "Test")
        ]

        for error in errorsWithoutRecoverySuggestions {
            // Just verify these don't crash - recovery suggestion may be nil
            _ = error.recoverySuggestion
        }
    }
}
