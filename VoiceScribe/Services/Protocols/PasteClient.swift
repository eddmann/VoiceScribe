import Foundation

@MainActor
protocol PasteClient: Sendable {
    var hasAccessibilityPermission: Bool { get }
    func openAccessibilitySettings()
    func simulatePasteWithDelay(delay: TimeInterval) async -> Bool
}
