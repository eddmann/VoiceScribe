import Foundation

@MainActor
enum AppCompletionClient {
    static func live(
        historyRepository: any HistoryRepositoryProtocol,
        clipboardClient: any ClipboardClient,
        focusClient: any AppFocusClient,
        pasteClient: any PasteClient,
        notificationCenter: NotificationCenter = .default,
        sleep: @escaping @Sendable (Duration) async -> Void = { duration in
            try? await Task.sleep(for: duration)
        }
    ) -> CompletionClient {
        CompletionClient(
            finish: { original, processed, audioURL, settings in
                let finalText = processed?.text ?? original.text
                await MainActor.run {
                    clipboardClient.copy(finalText)
                }
                await historyRepository.saveTranscription(
                    original: original,
                    processed: processed,
                    audioURL: audioURL
                )

                guard settings.smartPasteEnabled else {
                    return false
                }

                let canPaste = await MainActor.run {
                    pasteClient.hasAccessibilityPermission &&
                    focusClient.hasPreviousApplication &&
                    focusClient.restorePreviousApplication()
                }

                guard canPaste else {
                    return false
                }

                await sleep(.milliseconds(200))
                let pasted = await pasteClient.simulatePasteWithDelay(delay: 0.1)
                if pasted {
                    await MainActor.run {
                        notificationCenter.post(name: .closeRecordingWindow, object: nil)
                    }
                }
                return pasted
            }
        )
    }
}
