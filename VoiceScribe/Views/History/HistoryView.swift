import SwiftUI
import SwiftData

/// History view showing past transcriptions
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse) private var allRecords: [TranscriptionRecord]

    @State private var copiedRecordID: UUID?
    @AppStorage(SettingsKeys.historyLimit) private var historyLimit: Int = 25

    private var limitedRecords: [TranscriptionRecord] {
        Array(allRecords.prefix(historyLimit))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Transcription History")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(limitedRecords.count) of \(allRecords.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Content
            if limitedRecords.isEmpty {
                emptyStateView
            } else {
                transcriptionList
            }
        }
        .frame(width: 700, height: 500)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Transcriptions Yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Your transcription history will appear here")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transcriptionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(limitedRecords) { record in
                    TranscriptionRow(
                        record: record,
                        isCopied: copiedRecordID == record.id,
                        onCopy: {
                            copyToClipboard(record)
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if record.id != limitedRecords.last?.id {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func copyToClipboard(_ record: TranscriptionRecord) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(record.text, forType: .string)

        // Show feedback
        copiedRecordID = record.id

        // Clear feedback after 2 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if copiedRecordID == record.id {
                copiedRecordID = nil
            }
        }
    }
}

// MARK: - Transcription Row

struct TranscriptionRow: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Service Badge
            VStack(spacing: 4) {
                serviceBadge
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(serviceColor.opacity(0.15))
                    .foregroundStyle(serviceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Duration
                Text(formatDuration(record.audioDuration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(record.text)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(record.timestamp.relativeTimeString())
                        .font(.caption)

                    Spacer()

                    if isCopied {
                        Label("Copied!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Copy Button
            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy()
        }
    }

    private var serviceBadge: some View {
        switch record.serviceUsed.lowercased() {
        case "whisperkit":
            return Text("WhisperKit")
        case "openai":
            return Text("OpenAI")
        default:
            return Text(record.serviceUsed)
        }
    }

    private var serviceColor: Color {
        switch record.serviceUsed.lowercased() {
        case "whisperkit":
            return .blue
        case "openai":
            return .green
        default:
            return .gray
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: TranscriptionRecord.self, inMemory: true)
}
