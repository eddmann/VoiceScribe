import Foundation

@MainActor
protocol HistoryRepositoryProtocol: Sendable {
    func saveTranscription(text: String, serviceIdentifier: String, audioURL: URL) async
}
