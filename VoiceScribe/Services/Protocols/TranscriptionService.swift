import Foundation

/// Protocol defining a transcription service
/// All implementations must be thread-safe (Sendable) and use async/await
protocol TranscriptionService: Sendable {
    /// Human-readable name of the service (e.g., "OpenAI Whisper", "Local WhisperKit")
    var name: String { get }

    /// Unique identifier for the service (e.g., "openai", "whisperkit")
    var identifier: String { get }

    /// Whether this service requires an API key
    var requiresAPIKey: Bool { get }

    /// Whether this service is currently available/configured
    var isAvailable: Bool { get async }

    /// Optional progress handler for transcription operations
    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async

    /// Reload any model/user preferences before transcription
    func reloadModelFromPreferences() async

    /// Transcribe audio from a file URL
    /// - Parameter audioURL: URL to the audio file (must be accessible)
    /// - Returns: Transcribed text
    /// - Throws: VoiceScribeError if transcription fails
    func transcribe(audioURL: URL) async throws -> String

    /// Validate the current configuration (API key, model availability, etc.)
    /// - Throws: VoiceScribeError if configuration is invalid
    func validateConfiguration() async throws
}

/// Service configuration status
enum ServiceStatus: Sendable {
    case ready
    case notConfigured
    case configuring
    case error(VoiceScribeError)

    var isReady: Bool {
        if case .ready = self {
            return true
        }
        return false
    }
}
