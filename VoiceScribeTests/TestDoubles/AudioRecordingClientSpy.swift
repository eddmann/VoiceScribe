import Foundation
@testable import VoiceScribe

@MainActor
final class AudioRecordingClientSpy: AudioRecordingClient {
    var hasPermission: Bool
    var requestPermissionResult: Bool
    var startRecordingResult: Result<URL, Error>
    var stopRecordingResult: Result<URL, Error>
    var audioLevel: Float

    private(set) var requestPermissionCalls = 0
    private(set) var startRecordingCalls = 0
    private(set) var stopRecordingCalls = 0
    private(set) var cancelRecordingCalls = 0

    init(
        hasPermission: Bool = true,
        requestPermissionResult: Bool = true,
        startRecordingResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/voicescribe-audio.m4a")),
        stopRecordingResult: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/voicescribe-audio.m4a")),
        audioLevel: Float = 0.0
    ) {
        self.hasPermission = hasPermission
        self.requestPermissionResult = requestPermissionResult
        self.startRecordingResult = startRecordingResult
        self.stopRecordingResult = stopRecordingResult
        self.audioLevel = audioLevel
    }

    func requestPermission() async -> Bool {
        requestPermissionCalls += 1
        return requestPermissionResult
    }

    func startRecording() async throws -> URL {
        startRecordingCalls += 1
        return try startRecordingResult.get()
    }

    func stopRecording() async throws -> URL {
        stopRecordingCalls += 1
        return try stopRecordingResult.get()
    }

    func cancelRecording() async {
        cancelRecordingCalls += 1
    }

    func getAudioLevel() -> Float {
        audioLevel
    }
}
