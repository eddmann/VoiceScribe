import Foundation
@testable import VoiceScribe

@MainActor
final class PasteClientSpy: PasteClient {
    var hasAccessibilityPermission: Bool
    var simulateResult: Bool

    private(set) var openAccessibilitySettingsCalls = 0
    private(set) var simulatePasteCalls: [TimeInterval] = []

    init(hasAccessibilityPermission: Bool = true, simulateResult: Bool = true) {
        self.hasAccessibilityPermission = hasAccessibilityPermission
        self.simulateResult = simulateResult
    }

    func openAccessibilitySettings() {
        openAccessibilitySettingsCalls += 1
    }

    func simulatePasteWithDelay(delay: TimeInterval) async -> Bool {
        simulatePasteCalls.append(delay)
        return simulateResult
    }
}
