#if DEBUG
import XCTest
@testable import VoiceScribe

@MainActor
final class DemoDataFactoryTests: XCTestCase {
    func test_makePipelineState_recording_setsRecordingPhaseAndWaveform() {
        let state = DemoDataFactory.makePipelineState(for: .recording)

        XCTAssertEqual(state.phase, .recording)
        XCTAssertEqual(state.audioLevelHistory.count, 40)
        XCTAssertNotNil(state.recordingStartDate)
    }

    func test_makePipelineState_completed_setsCompletedPhaseAndLatestRun() {
        let state = DemoDataFactory.makePipelineState(for: .completed)

        XCTAssertEqual(
            state.phase,
            .completed(
                text: "Meeting notes: We discussed the Q1 roadmap and agreed to prioritize the mobile app redesign.",
                pasted: true
            )
        )
        XCTAssertEqual(state.latestRun?.processed?.engine, "Local LLM")
    }
}
#endif
