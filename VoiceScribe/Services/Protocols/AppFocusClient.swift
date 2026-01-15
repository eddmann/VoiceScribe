import Foundation

@MainActor
protocol AppFocusClient: Sendable {
    func capturePreviousApplication()
    func restorePreviousApplication() -> Bool
    var hasPreviousApplication: Bool { get }
}
