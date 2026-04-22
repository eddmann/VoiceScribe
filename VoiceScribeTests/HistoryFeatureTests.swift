import XCTest
import ComposableArchitecture
@testable import VoiceScribe

@MainActor
final class HistoryFeatureTests: XCTestCase {
    func test_copyTapped_copiesTextAndMarksCopiedRecord() async {
        let clipboardSpy = ClipboardClientSpy()
        let id = UUID()

        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature(
                clipboardClient: clipboardSpy,
                copyFeedbackDuration: .zero
            )
        }

        await store.send(.copyTapped(id, "Processed transcript")) {
            $0.copiedRecordID = id
        }

        XCTAssertEqual(clipboardSpy.copiedTexts, ["Processed transcript"])
    }

    func test_clearCopied_matchingRecordID_clearsCopyFeedback() async {
        let clipboardSpy = ClipboardClientSpy()
        let id = UUID()

        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature(
                clipboardClient: clipboardSpy,
                copyFeedbackDuration: .zero
            )
        }

        await store.send(.copyTapped(id, "Original transcript")) {
            $0.copiedRecordID = id
        }

        await store.send(.clearCopied(id)) {
            $0.copiedRecordID = nil
        }
    }

    func test_clearCopied_nonMatchingRecordID_leavesCopyFeedbackUntouched() async {
        let clipboardSpy = ClipboardClientSpy()
        let copiedID = UUID()
        let otherID = UUID()

        let store = TestStore(initialState: HistoryFeature.State()) {
            HistoryFeature(
                clipboardClient: clipboardSpy,
                copyFeedbackDuration: .zero
            )
        }

        await store.send(.copyTapped(copiedID, "Processed transcript")) {
            $0.copiedRecordID = copiedID
        }

        await store.send(.clearCopied(otherID))

        XCTAssertEqual(store.state.copiedRecordID, copiedID)
    }
}
