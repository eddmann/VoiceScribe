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
    /// Configures the AppState for the specified demo mode.
    @MainActor
    static func configure(_ appState: AppState, for mode: DemoMode) {
        switch mode {
        case .idle:
            appState.applyDemoState(
                recordingState: .idle,
                audioLevelHistory: generateFlatWaveform()
            )

        case .recording:
            appState.applyDemoState(
                recordingState: .recording,
                audioLevelHistory: generateActiveWaveform(),
                recordingStartDate: Date().addingTimeInterval(-15)
            )

        case .processing:
            appState.applyDemoState(
                recordingState: .processing(progress: "Transcribing..."),
                audioLevelHistory: generateFlatWaveform()
            )

        case .completed:
            let sampleText = "Meeting notes: We discussed the Q1 roadmap and agreed to prioritize the mobile app redesign."
            appState.applyDemoState(
                recordingState: .completed(text: sampleText, pasted: true, smartPasteAttempted: true),
                audioLevelHistory: generateFlatWaveform()
            )

        case .error:
            appState.applyDemoState(
                recordingState: .error("Network connection failed"),
                audioLevelHistory: generateFlatWaveform()
            )

        case .historyPopulated, .historyEmpty:
            // History modes don't need AppState configuration
            // They use SwiftData which is configured separately
            appState.applyDemoState(
                recordingState: .idle,
                audioLevelHistory: generateFlatWaveform()
            )
        }
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
                text: "Hey, can you send me the updated design files when you get a chance? I want to review them before our meeting tomorrow.",
                timestamp: Date().addingTimeInterval(-300),
                serviceUsed: "WhisperKit",
                audioDuration: 8.5
            ),
            TranscriptionRecord(
                text: "Meeting notes: We discussed the Q1 roadmap and agreed to prioritize the mobile app redesign. Next steps include finalizing wireframes by Friday.",
                timestamp: Date().addingTimeInterval(-3600),
                serviceUsed: "OpenAI",
                audioDuration: 15.2
            ),
            TranscriptionRecord(
                text: "Remember to pick up groceries on the way home. We need milk, eggs, and bread.",
                timestamp: Date().addingTimeInterval(-7200),
                serviceUsed: "WhisperKit",
                audioDuration: 5.8
            ),
            TranscriptionRecord(
                text: "The project deadline has been moved to next Thursday. Please update your calendars and let me know if you have any conflicts.",
                timestamp: Date().addingTimeInterval(-86400),
                serviceUsed: "OpenAI",
                audioDuration: 12.3
            ),
            TranscriptionRecord(
                text: "Quick note to self: Follow up with the marketing team about the launch campaign assets.",
                timestamp: Date().addingTimeInterval(-172800),
                serviceUsed: "WhisperKit",
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
