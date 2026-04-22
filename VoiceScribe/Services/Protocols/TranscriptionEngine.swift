import Foundation

/// Protocol defining a transcription engine.
/// All implementations must be thread-safe (Sendable) and use async/await.
protocol TranscriptionEngine: Sendable {
    /// Human-readable engine name (e.g., "Whisper", "Parakeet")
    var name: String { get }

    /// Unique identifier for the engine (e.g., "whisper", "parakeet")
    var identifier: String { get }

    /// Whether this engine is currently available/configured.
    var isAvailable: Bool { get async }

    /// Optional progress handler for transcription operations
    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async

    /// Reload any model/user preferences before transcription
    func reloadModelFromPreferences() async

    /// Transcribe audio from a file URL
    /// - Parameter audioURL: URL to the audio file (must be accessible)
    /// - Returns: Structured transcription result
    /// - Throws: VoiceScribeError if transcription fails
    func transcribe(audioURL: URL) async throws -> TranscriptionResult

    /// Validate the current configuration (model availability, etc.)
    /// - Throws: VoiceScribeError if configuration is invalid
    func validateConfiguration() async throws

    /// Human-readable model name for the current selection.
    func currentModelName() async -> String
}

/// Engine configuration status.
enum EngineStatus: Sendable {
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
