import Foundation
@testable import VoiceScribe

actor TranscriptionServiceStub: TranscriptionService {
    nonisolated let name: String
    nonisolated let identifier: String
    nonisolated let requiresAPIKey: Bool

    private var isAvailableValue: Bool
    private var progressHandler: (@Sendable (String) -> Void)?

    var transcribeResult: Result<String, Error>
    var validateResult: Error?

    init(
        name: String = "Stub Service",
        identifier: String = "stub",
        requiresAPIKey: Bool = false,
        isAvailable: Bool = true,
        transcribeResult: Result<String, Error> = .success("Stub transcription"),
        validateResult: Error? = nil
    ) {
        self.name = name
        self.identifier = identifier
        self.requiresAPIKey = requiresAPIKey
        self.isAvailableValue = isAvailable
        self.transcribeResult = transcribeResult
        self.validateResult = validateResult
    }

    var isAvailable: Bool {
        get async { isAvailableValue }
    }

    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async {
        progressHandler = handler
    }

    func reloadModelFromPreferences() async {
    }

    func transcribe(audioURL: URL) async throws -> String {
        progressHandler?("Transcribing")
        return try transcribeResult.get()
    }

    func validateConfiguration() async throws {
        if let error = validateResult {
            throw error
        }
    }

    func setIsAvailable(_ value: Bool) {
        isAvailableValue = value
    }

    func emitProgress(_ message: String) {
        progressHandler?(message)
    }
}
