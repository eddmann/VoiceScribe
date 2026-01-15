import Foundation
@testable import VoiceScribe

@MainActor
final class AppFocusClientSpy: AppFocusClient {
    var hasPreviousApplication: Bool
    var restoreResult: Bool

    private(set) var capturePreviousApplicationCalls = 0
    private(set) var restorePreviousApplicationCalls = 0

    init(hasPreviousApplication: Bool = false, restoreResult: Bool = true) {
        self.hasPreviousApplication = hasPreviousApplication
        self.restoreResult = restoreResult
    }

    func capturePreviousApplication() {
        capturePreviousApplicationCalls += 1
    }

    func restorePreviousApplication() -> Bool {
        restorePreviousApplicationCalls += 1
        return restoreResult
    }
}
