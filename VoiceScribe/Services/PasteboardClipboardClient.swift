import AppKit

@MainActor
struct PasteboardClipboardClient: ClipboardClient {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
