import Foundation

/// Protocol defining an optional local cleanup engine.
protocol CleanupEngine: Sendable {
    /// Human-readable engine name (e.g. "Local LLM")
    var name: String { get }

    /// Update the progress callback used while cleaning a transcript.
    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async

    /// Reload the current user-selected model before processing.
    func reloadModelFromPreferences() async

    /// Human-readable model name for the current selection.
    func currentModelName() async -> String

    /// Whether the engine can run right now with the selected model.
    func isReady() async -> Bool

    /// Improve a transcript and return the cleaned text.
    func postProcess(text: String) async throws -> String
}
