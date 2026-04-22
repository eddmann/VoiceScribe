//
//  DemoDataFactory.swift
//  VoiceScribe
//
//  Created by Edd on 2026-02-02.
//

#if DEBUG
import Foundation
import SwiftData

/// Factory for creating demo state for App Store screenshots.
enum DemoDataFactory {
    static func makePipelineState(for mode: DemoMode) -> PipelineFeature.State {
        var state = PipelineFeature.State()

        switch mode {
        case .idle:
            state.audioLevelHistory = generateFlatWaveform()

        case .recording:
            state.phase = .recording
            state.audioLevelHistory = generateActiveWaveform()
            state.recordingStartDate = Date().addingTimeInterval(-15)

        case .processing:
            state.phase = .transcribing("Transcribing with Whisper...")
            state.audioLevelHistory = generateFlatWaveform()

        case .completed:
            let sampleText = "Meeting notes: We discussed the Q1 roadmap and agreed to prioritize the mobile app redesign."
            state.latestRun = TranscriptRun(
                original: TranscriptArtifact(
                    text: sampleText,
                    engine: "Whisper",
                    model: "Balanced — Distil Large v3"
                ),
                processed: TranscriptArtifact(
                    text: sampleText,
                    engine: "Local LLM",
                    model: "Fast — Qwen3 1.7B"
                )
            )
            state.phase = .completed(text: sampleText, pasted: true)
            state.audioLevelHistory = generateFlatWaveform()

        case .error:
            state.phase = .error("Transcription failed")
            state.audioLevelHistory = generateFlatWaveform()

        case .historyPopulated, .historyEmpty:
            state.audioLevelHistory = generateFlatWaveform()
        }

        return state
    }

    /// Populates the model context with sample transcription records.
    @MainActor
    static func populateHistory(context: ModelContext) {
        let records = createSampleRecords()
        for record in records {
            context.insert(record)
        }
        try? context.save()
    }

    // MARK: - Sample Data Generation

    private static func createSampleRecords() -> [TranscriptionRecord] {
        [
            TranscriptionRecord(
                original: TranscriptArtifact(
                    text: "hey can you send me the updated design files when you get a chance i want to review them before our meeting tomorrow",
                    engine: "Whisper",
                    model: "Balanced — Distil Large v3"
                ),
                processed: TranscriptArtifact(
                    text: "Hey, can you send me the updated design files when you get a chance? I want to review them before our meeting tomorrow.",
                    engine: "Local LLM",
                    model: "Balanced — Llama 3.2 3B"
                ),
                timestamp: Date().addingTimeInterval(-300),
                audioDuration: 8.5
            ),
            TranscriptionRecord(
                original: TranscriptArtifact(
                    text: "Meeting notes we discussed the Q1 roadmap and agreed to prioritize the mobile app redesign next steps include finalizing wireframes by friday",
                    engine: "Parakeet",
                    model: "English v2"
                ),
                processed: TranscriptArtifact(
                    text: "Meeting notes: We discussed the Q1 roadmap and agreed to prioritize the mobile app redesign. Next steps include finalizing wireframes by Friday.",
                    engine: "Local LLM",
                    model: "Fast — Qwen3 1.7B"
                ),
                timestamp: Date().addingTimeInterval(-3600),
                audioDuration: 15.2
            ),
            TranscriptionRecord(
                original: TranscriptArtifact(
                    text: "Remember to pick up groceries on the way home. We need milk, eggs, and bread.",
                    engine: "Whisper",
                    model: "Fast — Small"
                ),
                timestamp: Date().addingTimeInterval(-7200),
                audioDuration: 5.8
            ),
            TranscriptionRecord(
                original: TranscriptArtifact(
                    text: "The project deadline has been moved to next Thursday. Please update your calendars and let me know if you have any conflicts.",
                    engine: "Parakeet",
                    model: "Multilingual v3"
                ),
                timestamp: Date().addingTimeInterval(-86400),
                audioDuration: 12.3
            ),
            TranscriptionRecord(
                original: TranscriptArtifact(
                    text: "Quick note to self: Follow up with the marketing team about the launch campaign assets.",
                    engine: "Whisper",
                    model: "Best — Large v3"
                ),
                timestamp: Date().addingTimeInterval(-172800),
                audioDuration: 6.1
            ),
        ]
    }

    // MARK: - Waveform Generation

    private static func generateFlatWaveform() -> [Float] {
        Array(repeating: 0.0, count: 40)
    }

    private static func generateActiveWaveform() -> [Float] {
        // Generate a realistic-looking waveform pattern
        var waveform: [Float] = []
        for i in 0..<40 {
            // Create a varied pattern that looks like natural speech
            let base = sin(Double(i) * 0.3) * 0.3
            let variation = Double.random(in: 0.1...0.6)
            let combined = Float(max(0.1, min(1.0, base + variation)))
            waveform.append(combined)
        }
        return waveform
    }
}
#endif
