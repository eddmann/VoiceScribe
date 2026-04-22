import XCTest
import SwiftData
@testable import VoiceScribe

@MainActor
final class AppCompletionClientTests: XCTestCase {
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

    func test_finish_copiesProcessedTextAndPersistsArtifacts() async throws {
        let container = try makeInMemoryContainer()
        let historyRepository = HistoryRepository(modelContext: container.mainContext)
        let clipboardSpy = ClipboardClientSpy()
        let focusClient = AppFocusClientFake(hasPreviousApplication: false, restorePreviousApplicationResult: false)
        let pasteClient = PasteClientFake(hasAccessibilityPermission: false, simulatedPasteResult: false)
        let completionClient = AppCompletionClient.live(
            historyRepository: historyRepository,
            clipboardClient: clipboardSpy,
            focusClient: focusClient,
            pasteClient: pasteClient,
            sleep: { _ in }
        )

        let original = TranscriptArtifact(text: "hello world", engine: "Parakeet", model: "English — English v2")
        let processed = TranscriptArtifact(text: "Hello, world.", engine: "Local LLM", model: "Balanced — Llama 3.2 3B")
        let settings = PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "parakeet",
            whisperModel: .small,
            parakeetModel: .englishV2,
            localLLMEnabled: true,
            localLLMModel: .llama3_2_3b,
            smartPasteEnabled: false,
            autoStartRecordingFromShortcut: false,
            historyLimit: 25
        )

        let pasted = await completionClient.finish(
            original,
            processed,
            URL(fileURLWithPath: "/tmp/completion-client-processed.m4a"),
            settings
        )

        XCTAssertFalse(pasted)
        XCTAssertEqual(clipboardSpy.copiedTexts, ["Hello, world."])

        let records = try fetchRecords(from: container)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].original, original)
        XCTAssertEqual(records[0].processed, processed)
    }

    func test_finish_withSmartPasteEnabled_attemptsPasteAndPostsCloseNotification() async throws {
        let container = try makeInMemoryContainer()
        let historyRepository = HistoryRepository(modelContext: container.mainContext)
        let clipboardSpy = ClipboardClientSpy()
        let focusClient = AppFocusClientFake(hasPreviousApplication: true, restorePreviousApplicationResult: true)
        let pasteClient = PasteClientFake(hasAccessibilityPermission: true, simulatedPasteResult: true)
        let notificationCenter = NotificationCenter()
        let observer = NotificationObserver(center: notificationCenter, name: .closeRecordingWindow)
        let completionClient = AppCompletionClient.live(
            historyRepository: historyRepository,
            clipboardClient: clipboardSpy,
            focusClient: focusClient,
            pasteClient: pasteClient,
            notificationCenter: notificationCenter,
            sleep: { _ in }
        )

        let settings = PipelineSettingsSnapshot(
            selectedTranscriptionEngine: "whisper",
            whisperModel: .small,
            parakeetModel: .englishV2,
            localLLMEnabled: false,
            localLLMModel: .qwen3_1_7b,
            smartPasteEnabled: true,
            autoStartRecordingFromShortcut: false,
            historyLimit: 25
        )

        let original = TranscriptArtifact(text: "raw transcript", engine: "Whisper", model: "Fast — Small")

        let pasted = await completionClient.finish(
            original,
            nil,
            URL(fileURLWithPath: "/tmp/completion-client-paste.m4a"),
            settings
        )

        XCTAssertTrue(pasted)
        XCTAssertEqual(clipboardSpy.copiedTexts, ["raw transcript"])
        XCTAssertEqual(focusClient.restoreAttempts(), 1)
        XCTAssertEqual(pasteClient.pasteAttempts(), 1)
        XCTAssertEqual(observer.notificationsReceived, 1)

        let records = try fetchRecords(from: container)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].original, original)
        XCTAssertNil(records[0].processed)
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

@MainActor
private final class AppFocusClientFake: AppFocusClient {
    let hasPreviousApplication: Bool
    private let restorePreviousApplicationResult: Bool
    private var restoreCount = 0

    init(hasPreviousApplication: Bool, restorePreviousApplicationResult: Bool) {
        self.hasPreviousApplication = hasPreviousApplication
        self.restorePreviousApplicationResult = restorePreviousApplicationResult
    }

    func capturePreviousApplication() {}

    func restorePreviousApplication() -> Bool {
        restoreCount += 1
        return restorePreviousApplicationResult
    }

    func restoreAttempts() -> Int {
        restoreCount
    }
}

@MainActor
private final class PasteClientFake: PasteClient {
    let hasAccessibilityPermission: Bool
    private let simulatedPasteResult: Bool
    private var pasteCount = 0

    init(hasAccessibilityPermission: Bool, simulatedPasteResult: Bool) {
        self.hasAccessibilityPermission = hasAccessibilityPermission
        self.simulatedPasteResult = simulatedPasteResult
    }

    func openAccessibilitySettings() {}

    func simulatePasteWithDelay(delay: TimeInterval) async -> Bool {
        pasteCount += 1
        return simulatedPasteResult
    }

    func pasteAttempts() -> Int {
        pasteCount
    }
}

@MainActor
private final class NotificationObserver {
    private(set) var notificationsReceived = 0
    private var token: NSObjectProtocol?

    init(center: NotificationCenter, name: Notification.Name) {
        token = center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
            self?.notificationsReceived += 1
        }
    }
}
