import SwiftUI

/// Main recording window view
struct RecordingView: View {
    @Environment(AppState.self) private var appState

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("VoiceScribe")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)

            // Status indicator
            StatusView(state: appState.recordingState, audioLevel: appState.audioLevel)

            // Main action button
            actionButton

            // Instructions
            instructionsText
        }
        .padding(20)
        .frame(width: 280, height: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .focusable()  // Allow view to receive keyboard focus
    }

    @ViewBuilder
    private var actionButton: some View {
        Button {
            handleMainAction()
        } label: {
            RecordingButton(isRecording: appState.recordingState.isRecording)
        }
        .buttonStyle(.plain)
        .disabled(appState.recordingState.isProcessing)
        .keyboardShortcut(.space, modifiers: [])
    }

    @ViewBuilder
    private var instructionsText: some View {
        Text(instructionsMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private var instructionsMessage: String {
        switch appState.recordingState {
        case .idle:
            return "Press Space to record • ESC to close"
        case .recording:
            return "Press Space to stop • ESC to cancel"
        case .processing:
            return "Processing audio..."
        case .completed:
            return "Text copied to clipboard!"
        case .error:
            return "Press Space to try again"
        }
    }

    private func handleMainAction() {
        Task {
            switch appState.recordingState {
            case .idle, .completed, .error:
                await appState.startRecording()
            case .recording:
                await appState.stopRecording()
            case .processing:
                break
            }
        }
    }
}

/// Recording button with visual feedback
struct RecordingButton: View {
    let isRecording: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isRecording ? Color.red : Color.blue)
                .frame(width: 80, height: 80)

            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 32))
                .foregroundStyle(.white)
        }
        .shadow(color: (isRecording ? Color.red : Color.blue).opacity(0.3), radius: 8)
    }
}

/// Status indicator view
struct StatusView: View {
    let state: RecordingState
    let audioLevel: Float

    var body: some View {
        HStack(spacing: 8) {
            // Status icon
            statusIcon

            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(statusColor)

            if state.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .recording:
            // Audio level visualization
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelBarColor(for: index))
                        .frame(width: 3, height: barHeight(for: index))
                        .animation(.easeInOut(duration: 0.1), value: audioLevel)
                }
            }
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .processing:
            EmptyView()
        case .idle:
            EmptyView()
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let threshold = Float(index) * 0.2
        return audioLevel > threshold ? 16 : 8
    }

    private func levelBarColor(for index: Int) -> Color {
        let threshold = Float(index) * 0.2
        return audioLevel > threshold ? .green : .gray.opacity(0.3)
    }

    private var statusText: String {
        switch state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing(let progress):
            return progress
        case .completed:
            return "Success!"
        case .error(let message):
            return message
        }
    }

    private var statusColor: Color {
        switch state {
        case .idle:
            return .primary
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        }
    }
}

#Preview {
    RecordingView()
        .environment(AppState())
        .frame(width: 280, height: 200)
}
