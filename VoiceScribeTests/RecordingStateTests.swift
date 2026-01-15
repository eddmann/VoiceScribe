//
//  RecordingStateTests.swift
//  VoiceScribeTests
//

import XCTest
@testable import VoiceScribe

@MainActor
final class RecordingStateTests: XCTestCase {

    // MARK: - isRecording

    func test_idle_isNotRecording() {
        let state = RecordingState.idle
        XCTAssertFalse(state.isRecording)
    }

    func test_recording_isRecording() {
        let state = RecordingState.recording
        XCTAssertTrue(state.isRecording)
    }

    func test_processing_isNotRecording() {
        let state = RecordingState.processing(progress: "Transcribing...")
        XCTAssertFalse(state.isRecording)
    }

    func test_completed_isNotRecording() {
        let state = RecordingState.completed(text: "Hello", pasted: false)
        XCTAssertFalse(state.isRecording)
    }

    func test_error_isNotRecording() {
        let state = RecordingState.error("Something went wrong")
        XCTAssertFalse(state.isRecording)
    }

    // MARK: - isProcessing

    func test_idle_isNotProcessing() {
        let state = RecordingState.idle
        XCTAssertFalse(state.isProcessing)
    }

    func test_recording_isNotProcessing() {
        let state = RecordingState.recording
        XCTAssertFalse(state.isProcessing)
    }

    func test_processing_isProcessing() {
        let state = RecordingState.processing(progress: "Transcribing...")
        XCTAssertTrue(state.isProcessing)
    }

    func test_completed_isNotProcessing() {
        let state = RecordingState.completed(text: "Hello", pasted: false)
        XCTAssertFalse(state.isProcessing)
    }

    func test_error_isNotProcessing() {
        let state = RecordingState.error("Something went wrong")
        XCTAssertFalse(state.isProcessing)
    }

    // MARK: - Equatable

    func test_equatable_sameStates() {
        XCTAssertEqual(RecordingState.idle, RecordingState.idle)
        XCTAssertEqual(RecordingState.recording, RecordingState.recording)
        XCTAssertEqual(
            RecordingState.processing(progress: "Test"),
            RecordingState.processing(progress: "Test")
        )
        XCTAssertEqual(
            RecordingState.completed(text: "Hello", pasted: true),
            RecordingState.completed(text: "Hello", pasted: true)
        )
        XCTAssertEqual(
            RecordingState.error("Error"),
            RecordingState.error("Error")
        )
    }

    func test_equatable_differentStates() {
        XCTAssertNotEqual(RecordingState.idle, RecordingState.recording)
        XCTAssertNotEqual(
            RecordingState.processing(progress: "A"),
            RecordingState.processing(progress: "B")
        )
        XCTAssertNotEqual(
            RecordingState.completed(text: "Hello", pasted: true),
            RecordingState.completed(text: "Hello", pasted: false)
        )
    }
}
