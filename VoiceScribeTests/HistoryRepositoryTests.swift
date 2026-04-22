import XCTest
import SwiftData
@testable import VoiceScribe

@MainActor
final class HistoryRepositoryTests: XCTestCase {
    private var originalHistoryLimit: Any?

    override func setUp() {
        super.setUp()
        originalHistoryLimit = UserDefaults.standard.object(forKey: SettingsKeys.historyLimit)
        UserDefaults.standard.set(25, forKey: SettingsKeys.historyLimit)
    }

    override func tearDown() {
        if let originalHistoryLimit {
            UserDefaults.standard.set(originalHistoryLimit, forKey: SettingsKeys.historyLimit)
        } else {
            UserDefaults.standard.removeObject(forKey: SettingsKeys.historyLimit)
        }
        super.tearDown()
    }

    func test_saveTranscription_persistsOriginalArtifact() async throws {
        let container = try makeInMemoryContainer()
        let repository = HistoryRepository(modelContext: container.mainContext)
        let original = TranscriptArtifact(
            text: "raw transcript",
            engine: "Whisper",
            model: "Balanced — Distil Large v3"
        )

        await repository.saveTranscription(
            original: original,
            processed: nil,
            audioURL: URL(fileURLWithPath: "/tmp/history-original-only.m4a")
        )

        let records = try fetchRecords(from: container)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].original, original)
        XCTAssertNil(records[0].processed)
    }

    func test_saveTranscription_persistsProcessedArtifact() async throws {
        let container = try makeInMemoryContainer()
        let repository = HistoryRepository(modelContext: container.mainContext)
        let original = TranscriptArtifact(
            text: "hello world",
            engine: "Parakeet",
            model: "English — English v2"
        )
        let processed = TranscriptArtifact(
            text: "Hello, world.",
            engine: "Local LLM",
            model: "Balanced — Llama 3.2 3B"
        )

        await repository.saveTranscription(
            original: original,
            processed: processed,
            audioURL: URL(fileURLWithPath: "/tmp/history-with-processed.m4a")
        )

        let records = try fetchRecords(from: container)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].original, original)
        XCTAssertEqual(records[0].processed, processed)
    }

    func test_saveTranscription_respectsHistoryLimitCleanup() async throws {
        UserDefaults.standard.set(1, forKey: SettingsKeys.historyLimit)

        let container = try makeInMemoryContainer()
        let repository = HistoryRepository(modelContext: container.mainContext)

        await repository.saveTranscription(
            original: TranscriptArtifact(
                text: "first transcript",
                engine: "Whisper",
                model: "Fast — Small"
            ),
            processed: nil,
            audioURL: URL(fileURLWithPath: "/tmp/history-limit-first.m4a")
        )

        await repository.saveTranscription(
            original: TranscriptArtifact(
                text: "second transcript",
                engine: "Whisper",
                model: "Best — Large v3"
            ),
            processed: nil,
            audioURL: URL(fileURLWithPath: "/tmp/history-limit-second.m4a")
        )

        let records = try fetchRecords(from: container)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].original.text, "second transcript")
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TranscriptionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func fetchRecords(from container: ModelContainer) throws -> [TranscriptionRecord] {
        let descriptor = FetchDescriptor<TranscriptionRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try container.mainContext.fetch(descriptor)
    }
}
