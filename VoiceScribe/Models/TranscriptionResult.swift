import Foundation

/// Structured output from a transcription provider.
struct TranscriptionResult: Sendable, Equatable {
    enum Outcome: Sendable, Equatable {
        case success(String)
        case ignored(IgnoredReason)
    }

    enum IgnoredReason: String, Sendable, Equatable {
        case noSpeechDetected
        case emptyTranscription
    }

    struct Segment: Sendable, Equatable {
        let text: String
        let startTime: TimeInterval?
        let endTime: TimeInterval?
        let confidence: Double?

        nonisolated init(
            text: String,
            startTime: TimeInterval? = nil,
            endTime: TimeInterval? = nil,
            confidence: Double? = nil
        ) {
            self.text = text
            self.startTime = startTime
            self.endTime = endTime
            self.confidence = confidence
        }
    }

    let outcome: Outcome
    let segments: [Segment]
    let language: String?
    let averageConfidence: Double?

    nonisolated init(
        outcome: Outcome,
        segments: [Segment] = [],
        language: String? = nil,
        averageConfidence: Double? = nil
    ) {
        self.outcome = outcome
        self.segments = segments
        self.language = language
        self.averageConfidence = averageConfidence
    }

    nonisolated static func success(
        _ text: String,
        segments: [Segment] = [],
        language: String? = nil,
        averageConfidence: Double? = nil
    ) -> TranscriptionResult {
        TranscriptionResult(
            outcome: .success(text),
            segments: segments,
            language: language,
            averageConfidence: averageConfidence
        )
    }

    nonisolated static func ignored(
        _ reason: IgnoredReason,
        segments: [Segment] = [],
        language: String? = nil,
        averageConfidence: Double? = nil
    ) -> TranscriptionResult {
        TranscriptionResult(
            outcome: .ignored(reason),
            segments: segments,
            language: language,
            averageConfidence: averageConfidence
        )
    }

    nonisolated var text: String? {
        if case .success(let text) = outcome {
            return text
        }
        return nil
    }
}
