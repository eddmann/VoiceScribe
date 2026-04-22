import SwiftUI
import KeyboardShortcuts
import ComposableArchitecture

private enum SettingsTab {
    case transcription
    case cleanup
    case preferences
    case about

    var preferredHeight: CGFloat {
        switch self {
        case .transcription:
            return 320
        case .cleanup:
            return 305
        case .preferences:
            return 410
        case .about:
            return 390
        }
    }
}

struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    @State private var selectedTab: SettingsTab = .transcription

    init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            transcriptionTab
                .tabItem { Label("Transcription", systemImage: "waveform") }
                .tag(SettingsTab.transcription)

            cleanupTab
                .tabItem { Label("Cleanup", systemImage: "wand.and.stars") }
                .tag(SettingsTab.cleanup)

            preferencesTab
                .tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.preferences)

            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: 540, height: selectedTab.preferredHeight)
        .animation(.snappy(duration: 0.2), value: selectedTab)
        .onAppear {
            store.send(.appeared)
        }
        .onDisappear {
            store.send(.disappeared)
        }
    }

    private var transcriptionTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Engine")
                            .font(.headline)

                        Picker(
                            "",
                            selection: Binding(
                                get: { store.selectedTranscriptionEngine },
                                set: { store.send(.transcriptionEngineSelected($0)) }
                            )
                        ) {
                            Text("Whisper").tag("whisper")
                            Text("Parakeet").tag("parakeet")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Label(
                            selectedTranscriptionSummary(for: store.selectedTranscriptionEngine),
                            systemImage: store.selectedTranscriptionEngine == "parakeet" ? "waveform.path.ecg" : "waveform.badge.magnifyingglass"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                selectedTranscriptionModelSection

                if let downloadError = store.downloadError {
                    Label(downloadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(20)
        }
    }

    private var cleanupTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Local LLM")
                                    .font(.headline)

                                Text("Optional local cleanup stored alongside the original transcript.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { store.localLLMEnabled },
                                    set: { store.send(.localLLMEnabledChanged($0)) }
                                )
                            )
                            .labelsHidden()
                        }

                        HStack(spacing: 8) {
                            statusPill(
                                title: store.localLLMEnabled ? "Enabled" : "Optional",
                                tint: store.localLLMEnabled ? .green : .secondary
                            )

                            if store.localLLMEnabled {
                                statusPill(title: "Runs On-Device", tint: .blue)
                            }
                        }
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Cleanup Model")
                                .font(.headline)

                            Spacer()

                            localLLMModelAccessory(for: store.localLLMModel)
                        }

                        Picker(
                            "Local LLM Model",
                            selection: Binding(
                                get: { store.localLLMModel },
                                set: { store.send(.localLLMModelSelected($0)) }
                            )
                        ) {
                            ForEach(LocalLLMCleanupEngine.Model.allCases, id: \.self) { model in
                                Text("\(model.displayName) (\(model.approximateSize))").tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(!store.localLLMEnabled)

                        Text(store.localLLMModel.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        modelMetadataRow(
                            technicalName: store.localLLMModel.technicalModelName,
                            url: store.localLLMModel.huggingFaceURL
                        )
                    }
                    .opacity(store.localLLMEnabled ? 1 : 0.7)
                }

                if let downloadError = store.downloadError {
                    Label(downloadError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(20)
        }
    }

    private var preferencesTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                smartPasteSection
                keyboardShortcutSection
                historySection
                launchAtLoginSection
            }
            .padding(20)
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 24) {
            if let appIconImage = NSImage(named: "AppIcon") {
                Image(nsImage: appIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 8) {
                Text("VoiceScribe")
                    .font(.system(size: 28, weight: .semibold))

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("Version \(version) (\(build))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            VStack(spacing: 4) {
                Text("© 2026 Edd Mann")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Local transcription with optional local cleanup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/eddmann/VoiceScribe")!) {
                HStack {
                    Image(systemName: "link.circle.fill")
                    Text("View Project on GitHub")
                }
                .frame(maxWidth: 280)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var selectedTranscriptionModelSection: some View {
        if store.selectedTranscriptionEngine == "parakeet" {
            transcriptionModelCard(
                title: "Parakeet Model",
                description: store.parakeetModel.description
            ) {
                Picker(
                    "Parakeet Model",
                    selection: Binding(
                        get: { store.parakeetModel },
                        set: { store.send(.parakeetModelSelected($0)) }
                    )
                ) {
                    ForEach(ParakeetEngine.Model.allCases, id: \.self) { model in
                        Text("\(model.displayName) (\(model.approximateSize))").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            } accessory: {
                parakeetModelAccessory(for: store.parakeetModel)
            } metadata: {
                modelMetadataRow(
                    technicalName: store.parakeetModel.technicalModelName,
                    url: store.parakeetModel.huggingFaceURL
                )
            }
        } else {
            transcriptionModelCard(
                title: "Whisper Model",
                description: store.whisperModel.description
            ) {
                Picker(
                    "Whisper Model",
                    selection: Binding(
                        get: { store.whisperModel },
                        set: { store.send(.whisperModelSelected($0)) }
                    )
                ) {
                    ForEach(WhisperEngine.Model.allCases, id: \.self) { model in
                        Text("\(model.displayName) (\(model.approximateSize))").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            } accessory: {
                whisperModelAccessory(for: store.whisperModel)
            } metadata: {
                modelMetadataRow(
                    technicalName: store.whisperModel.technicalModelName,
                    url: store.whisperModel.huggingFaceURL
                )
            }
        }
    }

    private func transcriptionModelCard<PickerContent: View, Accessory: View, Metadata: View>(
        title: String,
        description: String,
        @ViewBuilder picker: () -> PickerContent,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder metadata: () -> Metadata
    ) -> some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)

                    Spacer()

                    accessory()
                }

                picker()

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                metadata()
            }
        }
    }

    private var smartPasteSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Toggle(
                        "Smart Paste",
                        isOn: Binding(
                            get: { store.smartPasteEnabled },
                            set: { store.send(.smartPasteEnabledChanged($0)) }
                        )
                    )
                    .font(.subheadline)
                    .disabled(!store.hasAccessibilityPermission)

                    Spacer()

                    if store.hasAccessibilityPermission {
                        statusPill(title: "Enabled", tint: .green)
                    } else {
                        Button(action: { store.send(.openAccessibilitySettingsTapped) }) {
                            Label("Grant Access", systemImage: "lock.shield")
                        }
                        .controlSize(.small)
                    }
                }

                Text("Automatically paste the final transcript into the previous app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var keyboardShortcutSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Shortcut")
                            .font(.subheadline)
                        Text("Default: ⌥⇧Space")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    KeyboardShortcuts.Recorder("", name: .toggleRecording)
                }

                Toggle(
                    "Start Recording Immediately",
                    isOn: Binding(
                        get: { store.autoStartRecordingFromShortcut },
                        set: { store.send(.autoStartRecordingFromShortcutChanged($0)) }
                    )
                )
                .font(.subheadline)
            }
        }
    }

    private var historySection: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History Limit")
                        .font(.subheadline)
                    Text("Older entries are automatically removed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(
                    "",
                    selection: Binding(
                        get: { store.historyLimit },
                        set: { store.send(.historyLimitSelected($0)) }
                    )
                ) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 80)
            }
        }
    }

    private var launchAtLoginSection: some View {
        SettingsCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start at Login")
                        .font(.subheadline)
                    Text("Automatically launch VoiceScribe when you log in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.send(.launchAtLoginChanged($0)) }
                    )
                )
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private func whisperModelAccessory(for model: WhisperEngine.Model) -> some View {
        if store.downloadingWhisperModels.contains(model) {
            ProgressView()
                .controlSize(.small)
        } else if store.downloadedWhisperModels.contains(model) {
            Button(role: .destructive) {
                store.send(.deleteWhisperModelTapped(model))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete model")
        } else {
            Button("Download") {
                store.send(.downloadWhisperModelTapped(model))
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func parakeetModelAccessory(for model: ParakeetEngine.Model) -> some View {
        if store.downloadingParakeetModels.contains(model) {
            ProgressView()
                .controlSize(.small)
        } else if store.downloadedParakeetModels.contains(model) {
            Button(role: .destructive) {
                store.send(.deleteParakeetModelTapped(model))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete model")
        } else {
            Button("Download") {
                store.send(.downloadParakeetModelTapped(model))
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private func localLLMModelAccessory(for model: LocalLLMCleanupEngine.Model) -> some View {
        if store.downloadingLocalLLMModels.contains(model) {
            ProgressView()
                .controlSize(.small)
        } else if store.downloadedLocalLLMModels.contains(model) {
            Button(role: .destructive) {
                store.send(.deleteLocalLLMModelTapped(model))
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete model")
        } else {
            Button("Download") {
                store.send(.downloadLocalLLMModelTapped(model))
            }
            .controlSize(.small)
        }
    }

    private func selectedTranscriptionSummary(for engine: String) -> String {
        switch engine {
        case "parakeet":
            return "Parakeet runs through FluidAudio Core ML models for fast, dictation-first transcription."
        default:
            return "Whisper runs through WhisperKit on Core ML for broader multilingual transcription."
        }
    }

    private func statusPill(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func modelMetadataRow(technicalName: String, url: URL) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(technicalName)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 0)

            Link(destination: url) {
                Label("Hugging Face", systemImage: "arrow.up.right.square")
                    .font(.caption)
            }
        }
    }
}

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    SettingsView(store: Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    })
}
