import Combine
import SwiftUI

/// Compact floating recording bar with waveform visualization
struct FloatingRecordBar: View {
    @Environment(AppState.self) private var appState
    @FocusState private var isBarFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Record/Stop button
            RecordStopButton(
                state: appState.recordingState,
                action: handleMainAction
            )

            // Waveform visualization
            WaveformCanvas(
                audioLevelHistory: appState.audioLevelHistory,
                isRecording: appState.recordingState.isRecording
            )
            .frame(maxWidth: .infinity)

            // Status area (duration or status text)
            StatusArea(
                state: appState.recordingState,
                recordingStartDate: appState.recordingStartDate
            )

            // Close button
            CloseButton()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: 360, height: 52)
        .background(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 4)
        .focusable()
        .focused($isBarFocused)
        .focusEffectDisabled()
        .onAppear {
            // Request focus after view is laid out to enable spacebar shortcut
            DispatchQueue.main.async {
                isBarFocused = true
            }
        }
        .onKeyPress(.space) {
            handleMainAction()
            return .handled
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

// MARK: - Record/Stop Button

private struct RecordStopButton: View {
    let state: RecordingState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(buttonColor)
                    .frame(width: 32, height: 32)

                buttonIcon
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(state.isProcessing)
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityLabel(accessibilityLabel)
    }

    private var buttonColor: Color {
        switch state {
        case .recording:
            return .red
        case .processing:
            return .orange
        case .completed:
            return .green
        case .error:
            return .red
        case .idle:
            return .blue
        }
    }

    @ViewBuilder
    private var buttonIcon: some View {
        switch state {
        case .idle:
            Image(systemName: "mic.fill")
        case .recording:
            Image(systemName: "stop.fill")
        case .processing:
            ProgressView()
                .scaleEffect(0.5)
                .tint(.white)
        case .completed:
            Image(systemName: "checkmark")
        case .error:
            Image(systemName: "exclamationmark")
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .idle: return "Start recording"
        case .recording: return "Stop recording"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .error: return "Error occurred"
        }
    }
}

// MARK: - Waveform Canvas

struct WaveformCanvas: View {
    let audioLevelHistory: [Float]
    let isRecording: Bool

    private let barCount = 40
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let minBarHeight: CGFloat = 4
    private let cornerRadius: CGFloat = 1.5

    var body: some View {
        Canvas { context, size in
            let totalBars = min(barCount, audioLevelHistory.count)
            let totalWidth = CGFloat(totalBars) * (barWidth + barSpacing) - barSpacing
            let startX = (size.width - totalWidth) / 2

            for index in 0..<totalBars {
                let level = audioLevelHistory[index]
                let x = startX + CGFloat(index) * (barWidth + barSpacing)

                // Apply smoothing curve for more natural appearance
                let smoothedLevel = smoothLevel(level)
                let maxHeight = size.height - 4
                let height = max(minBarHeight, maxHeight * CGFloat(smoothedLevel))
                let y = (size.height - height) / 2

                let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)

                // Color gradient based on level
                let color = barColor(for: smoothedLevel, isRecording: isRecording)
                context.fill(path, with: .color(color))
            }
        }
        .frame(height: 32)
        .animation(.easeOut(duration: 0.05), value: audioLevelHistory)
    }

    private func smoothLevel(_ level: Float) -> Float {
        // Apply exponential curve for more dramatic visual response
        let curved = pow(level, 0.7)
        return min(1.0, max(0.0, curved))
    }

    private func barColor(for level: Float, isRecording: Bool) -> Color {
        if !isRecording {
            return Color.gray.opacity(0.3)
        }

        // Gradient from gray to green based on level
        if level < 0.1 {
            return Color.gray.opacity(0.4)
        } else if level < 0.5 {
            return Color.green.opacity(0.6 + Double(level) * 0.4)
        } else {
            return Color.green.opacity(0.9 + Double(level) * 0.1)
        }
    }
}

// MARK: - Status Area

private struct StatusArea: View {
    let state: RecordingState
    let recordingStartDate: Date?

    var body: some View {
        Group {
            switch state {
            case .idle:
                Text("Space")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.gray)
            case .recording:
                DurationView(startDate: recordingStartDate)
            case .processing(let progress):
                processingText(progress)
            case .completed(_, let pasted, _):
                Text(pasted ? "Pasted!" : "Copied!")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.green)
            case .error:
                Text("Error")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
            }
        }
        .frame(width: 60)
    }

    @ViewBuilder
    private func processingText(_ progress: String) -> some View {
        // Show phase-aware processing status
        if progress.localizedCaseInsensitiveContains("post-processing") ||
           progress.localizedCaseInsensitiveContains("enhancing") {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .symbolEffect(.pulse, options: .repeating)
                Text("AI")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.orange)
        } else if progress.localizedCaseInsensitiveContains("downloading") {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                    .symbolEffect(.pulse, options: .repeating)
                Text("DL")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.orange)
        } else if progress.localizedCaseInsensitiveContains("loading") {
            HStack(spacing: 4) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                    .symbolEffect(.pulse, options: .repeating)
                Text("Load")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.orange)
        } else {
            // Default and transcribing states use bouncing dots
            BouncingDots()
        }
    }
}

// MARK: - Duration View

private struct DurationView: View {
    let startDate: Date?

    @State private var duration: TimeInterval = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            Text(formattedDuration)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private var formattedDuration: String {
        guard let start = startDate else { return "0:00" }
        let elapsed = Date().timeIntervalSince(start)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Bouncing Dots

private struct BouncingDots: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.orange)
                    .frame(width: 4, height: 4)
                    .offset(y: phase == index ? -3 : 0)
                    .animation(.easeInOut(duration: 0.2), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Close Button

private struct CloseButton: View {
    var body: some View {
        Button {
            // Post notification to close the window
            NotificationCenter.default.post(name: .closeRecordingWindow, object: nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 20, height: 20)
                .background(Color.gray.opacity(0.2))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
        .accessibilityLabel("Close")
    }
}

#Preview {
    FloatingRecordBar()
        .environment(AppState())
        .padding()
        .background(Color.black)
}
