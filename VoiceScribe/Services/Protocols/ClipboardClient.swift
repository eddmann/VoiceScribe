import Foundation

@MainActor
protocol ClipboardClient: Sendable {
    func copy(_ text: String)
}
