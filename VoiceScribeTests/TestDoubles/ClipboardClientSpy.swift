import Foundation
@testable import VoiceScribe

@MainActor
final class ClipboardClientSpy: ClipboardClient {
    private(set) var copiedTexts: [String] = []

    func copy(_ text: String) {
        copiedTexts.append(text)
    }
}
