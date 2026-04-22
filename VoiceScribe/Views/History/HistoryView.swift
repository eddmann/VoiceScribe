import SwiftUI
import SwiftData
import ComposableArchitecture

struct HistoryView: View {
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse) private var allRecords: [TranscriptionRecord]
    let store: StoreOf<HistoryFeature>

    init(store: StoreOf<HistoryFeature>) {
        self.store = store
    }

    var body: some View {
        let limitedRecords = Array(allRecords.prefix(store.historyLimit))

        VStack(spacing: 0) {
            header(limitedRecords: limitedRecords)

            Divider()

            if limitedRecords.isEmpty {
                emptyStateView
            } else {
                transcriptionList(limitedRecords: limitedRecords)
            }
        }
        .frame(width: 760, height: 560)
        .onAppear {
            store.send(.appeared)
        }
    }

    private func header(limitedRecords: [TranscriptionRecord]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Each entry keeps the original transcript and, when enabled, the cleaned version.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(limitedRecords.count) of \(allRecords.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Transcripts Yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Recorded transcripts will appear here once you start using VoiceScribe.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transcriptionList(limitedRecords: [TranscriptionRecord]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(limitedRecords) { record in
                    TranscriptionRow(
                        record: record,
                        isCopied: store.copiedRecordID == record.id,
                        onCopy: { text in
                            store.send(.copyTapped(record.id, text))
                        }
                    )
                }
            }
            .padding(20)
        }
    }
}

struct TranscriptionRow: View {
    let record: TranscriptionRecord
    let isCopied: Bool
    let onCopy: (String) -> Void
    @State private var selectedVariant: TranscriptVariant

    init(record: TranscriptionRecord, isCopied: Bool, onCopy: @escaping (String) -> Void) {
        self.record = record
        self.isCopied = isCopied
        self.onCopy = onCopy
        _selectedVariant = State(initialValue: record.processed != nil ? .processed : .original)
    }

    private var availableVariants: [TranscriptVariant] {
        if record.processed != nil {
            return [.processed, .original]
        } else {
            return [.original]
        }
    }

    private var activeArtifact: TranscriptArtifact {
        switch selectedVariant {
        case .original:
            return record.original
        case .processed:
            return record.processed ?? record.original
        }
    }

    private var copyLabel: String {
        switch selectedVariant {
        case .original:
            return "Copy Original"
        case .processed:
            return "Copy Processed"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if availableVariants.count > 1 {
                Picker("Transcript Version", selection: $selectedVariant) {
                    ForEach(availableVariants, id: \.self) { variant in
                        Text(variant.title).tag(variant)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            transcriptBlock(
                title: selectedVariant.title,
                artifact: activeArtifact,
                text: activeArtifact.text,
                accent: selectedVariant.accent
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.24))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.timestamp.relativeTimeString())
                    .font(.subheadline.weight(.medium))

                Text("\(formatDuration(record.audioDuration)) recording")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCopied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button(action: {
                onCopy(activeArtifact.text)
            }) {
                Label(copyLabel, systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func transcriptBlock(
        title: String,
        artifact: TranscriptArtifact,
        text: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)

                Text("\(artifact.engine) • \(artifact.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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

private enum TranscriptVariant: String, Hashable {
    case original
    case processed

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .processed:
            return "Processed"
        }
    }

    var accent: Color {
        switch self {
        case .original:
            return .blue
        case .processed:
            return .green
        }
    }
}

#Preview {
    HistoryView(
        store: Store(initialState: HistoryFeature.State()) {
            HistoryFeature()
        }
    )
        .modelContainer(for: TranscriptionRecord.self, inMemory: true)
}
