import SwiftUI

/// Main recording window view
struct RecordingView: View {
    @Environment(AppState.self) private var appState

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 20) {
            // Title with subtle glow
            Text("VoiceScribe")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            // Status indicator
            StatusView(state: appState.recordingState, audioLevel: appState.audioLevel)

            // Main action button
            actionButton

            // Instructions
            instructionsText
        }
        .padding(28)
        .frame(width: 300)
        .background {
            ZStack {
                // Glass effect base
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)

                // Gradient overlay for depth
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .focusable()  // Allow view to receive keyboard focus
        .focusEffectDisabled()  // Remove focus ring
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
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var instructionsMessage: String {
        switch appState.recordingState {
        case .idle:
            return "Press Space to record • ESC to close"
        case .recording:
            return "Press Space to stop • ESC to cancel"
        case .processing:
            return "Processing audio..."
        case .completed(_, let pasted, let smartPasteAttempted):
            if pasted {
                return "Text pasted!"
            } else if smartPasteAttempted {
                // Smart paste was enabled but failed (likely due to missing accessibility permission)
                return "Copied to clipboard (enable accessibility for auto-paste)"
            } else {
                // Smart paste was not enabled, just copied to clipboard
                return "Copied to clipboard!"
            }
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
            // Main button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            isRecording ? Color.red : Color.blue,
                            isRecording ? Color.red.opacity(0.8) : Color.blue.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }


            // Icon
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white)
                
        }
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
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if state.isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .frame(minHeight: 24)
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
        case .processing(let progress):
            // Show sparkle icon when post-processing
            if progress.localizedCaseInsensitiveContains("post-processing") ||
               progress.localizedCaseInsensitiveContains("enhancing") {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating)
            } else {
                EmptyView()
            }
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
