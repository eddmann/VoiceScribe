import Foundation
import SwiftData

/// A recorded transcription entry
@Model
final class TranscriptionRecord {
    /// Unique identifier
    var id: UUID

    /// The transcribed text
    var text: String

    /// When the transcription was created
    var timestamp: Date

    /// Which service was used (e.g., "openai", "whisperkit")
    var serviceUsed: String

    /// Duration of the audio in seconds
    var audioDuration: TimeInterval

    /// Optional: Path to the original audio file (if saved)
    var audioFilePath: String?

    init(
        id: UUID = UUID(),
        text: String,
        timestamp: Date = Date(),
        serviceUsed: String,
        audioDuration: TimeInterval,
        audioFilePath: String? = nil
    ) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.serviceUsed = serviceUsed
        self.audioDuration = audioDuration
        self.audioFilePath = audioFilePath
    }
}

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
