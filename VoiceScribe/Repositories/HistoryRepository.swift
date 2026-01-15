import AVFoundation
import Foundation
import SwiftData
import os.log

@MainActor
final class HistoryRepository: HistoryRepositoryProtocol {
    private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "HistoryRepository"
    )

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func saveTranscription(text: String, serviceIdentifier: String, audioURL: URL) async {
        let duration = await getAudioDuration(audioURL)

        let record = TranscriptionRecord(
            text: text,
            serviceUsed: serviceIdentifier,
            audioDuration: duration
        )

        modelContext.insert(record)

        do {
            try modelContext.save()
            cleanupOldRecords()
        } catch {
            Self.logger.error("Failed to save transcription: \(error.localizedDescription)")
        }
    }

    private func getAudioDuration(_ url: URL) async -> TimeInterval {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return 0
        }
    }

    private func cleanupOldRecords() {
        let historyLimit = UserDefaults.standard.integer(forKey: SettingsKeys.historyLimit)
        let limit = historyLimit > 0 ? historyLimit : 25

        do {
            let descriptor = FetchDescriptor<TranscriptionRecord>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let allRecords = try modelContext.fetch(descriptor)

            if allRecords.count > limit {
                let recordsToDelete = Array(allRecords.dropFirst(limit))
                for record in recordsToDelete {
                    modelContext.delete(record)
                }

                try modelContext.save()
                Self.logger.info("Cleaned up \(recordsToDelete.count) old transcription(s)")
            }
        } catch {
            Self.logger.error("Failed to cleanup old records: \(error.localizedDescription)")
        }
    }
}
