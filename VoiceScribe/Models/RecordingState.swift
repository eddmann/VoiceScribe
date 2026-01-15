import Foundation

/// Current state of the recording/transcription process
enum RecordingState: Sendable, Equatable {
    case idle
    case recording
    case processing(progress: String)
    case completed(text: String, pasted: Bool, smartPasteAttempted: Bool = false)
    case error(String)

    var isRecording: Bool {
        if case .recording = self {
            return true
        }
        return false
    }

    var isProcessing: Bool {
        if case .processing = self {
            return true
        }
        return false
    }
}
