import Foundation
import SwiftData

struct TranscriptArtifact: Codable, Equatable, Sendable {
    let text: String
    let engine: String
    let model: String

    nonisolated static func == (lhs: TranscriptArtifact, rhs: TranscriptArtifact) -> Bool {
        lhs.text == rhs.text &&
        lhs.engine == rhs.engine &&
        lhs.model == rhs.model
    }
}

/// A recorded transcription entry
@Model
final class TranscriptionRecord {
    var id: UUID
    var originalText: String = ""
    var originalEngine: String = ""
    var originalModel: String = ""
    var timestamp: Date
    var processedText: String?
    var processedEngine: String?
    var processedModel: String?
    var audioDuration: TimeInterval
    var audioFilePath: String?

    init(
        id: UUID = UUID(),
        original: TranscriptArtifact,
        processed: TranscriptArtifact? = nil,
        timestamp: Date = Date(),
        audioDuration: TimeInterval,
        audioFilePath: String? = nil
    ) {
        self.id = id
        self.originalText = original.text
        self.originalEngine = original.engine
        self.originalModel = original.model
        self.timestamp = timestamp
        self.processedText = processed?.text
        self.processedEngine = processed?.engine
        self.processedModel = processed?.model
        self.audioDuration = audioDuration
        self.audioFilePath = audioFilePath
    }

    var original: TranscriptArtifact {
        return TranscriptArtifact(
            text: originalText,
            engine: originalEngine,
            model: originalModel
        )
    }

    var processed: TranscriptArtifact? {
        guard let processedText,
              let processedEngine,
              let processedModel else {
            return nil
        }

        return TranscriptArtifact(
            text: processedText,
            engine: processedEngine,
            model: processedModel
        )
    }

    var displayText: String {
        processed?.text ?? original.text
    }
}
