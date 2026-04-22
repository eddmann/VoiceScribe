import Foundation

@MainActor
protocol HistoryRepositoryProtocol: Sendable {
    func saveTranscription(
        original: TranscriptArtifact,
        processed: TranscriptArtifact?,
        audioURL: URL
    ) async
}
