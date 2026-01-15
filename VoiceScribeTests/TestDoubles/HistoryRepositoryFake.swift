import Foundation
@testable import VoiceScribe

@MainActor
final class HistoryRepositoryFake: HistoryRepositoryProtocol {
    struct Entry: Equatable {
        let text: String
        let serviceIdentifier: String
        let audioURL: URL
    }

    private(set) var savedEntries: [Entry] = []

    func saveTranscription(text: String, serviceIdentifier: String, audioURL: URL) async {
        savedEntries.append(Entry(text: text, serviceIdentifier: serviceIdentifier, audioURL: audioURL))
    }
}
