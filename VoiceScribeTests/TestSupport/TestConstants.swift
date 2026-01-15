//
//  TestConstants.swift
//  VoiceScribeTests
//

import Foundation

enum TestConstants {
    // Audio
    static let testAudioURL = URL(fileURLWithPath: "/tmp/voicescribe-test.m4a")
    static let testAudioLevel: Float = 0.5

    // Transcription
    static let transcribedText = "Hello, this is a test transcription."
    static let serviceIdentifier = "stub"
    static let serviceName = "Stub Service"

    // Errors
    static let transcriptionFailureMessage = "Transcription failed"
    static let recordingFailureMessage = "Recording failed"
    static let noServiceErrorMessage = "No transcription service selected"

    // Timing
    static let processingProgress = "Transcribing with Stub Service..."
}
