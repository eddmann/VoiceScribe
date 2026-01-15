import SwiftUI
import KeyboardShortcuts
import ServiceManagement
import os.log

private let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "Settings")

/// Settings view for configuring transcription services
struct SettingsView: View {
    @Bindable var appState: AppState
    @Bindable var settings: SettingsStore

    @State private var openAIKey: String = ""
    @State private var showingAPIKeySaved = false
    @State private var downloadingModels: Set<WhisperKitService.Model> = []
    @State private var downloadedModels: [WhisperKitService.Model] = []
    @State private var downloadingMLXModels: Set<MLXService.Model> = []
    @State private var downloadedMLXModels: [MLXService.Model] = []
    @State private var downloadError: String?
    @State private var hasAccessibilityPermission = false
    @State private var permissionCheckTask: Task<Void, Never>?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    init(appState: AppState, settings: SettingsStore = .shared) {
        self.appState = appState
        self.settings = settings
    }

    var body: some View {
        contentView
            .onAppear {
                loadSettings()
                checkPermissionStatus()
                startPermissionCheckTimer()
            }
            .onDisappear {
                permissionCheckTask?.cancel()
                permissionCheckTask = nil
            }
    }

    private var contentView: some View {
        mainTabView
    }

    private var mainTabView: some View {
        TabView {
            transcriptionServiceTab
                .tabItem { Label("Service", systemImage: "waveform") }
            smartPasteTab
                .tabItem { Label("Preferences", systemImage: "slider.horizontal.3") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
    }

    // MARK: - Tab Views

    private var transcriptionServiceTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            serviceSelectionSection

            Divider()

            // Service-specific settings
            if settings.selectedServiceIdentifier == "openai" {
                openAISection
            } else if settings.selectedServiceIdentifier == "whisperkit" {
                whisperKitSection
            }
        }
        .padding(24)
    }

    private var smartPasteTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            smartPasteSection
            keyboardShortcutSection
            historySection
            launchAtLoginSection
        }
        .padding(24)
        .onChange(of: launchAtLogin) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.error("Failed to update launch at login: \(error.localizedDescription)")
                // Revert the toggle if it failed
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 24) {
            // App Icon
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

            // App Name & Version
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

            // Copyright
            VStack(spacing: 4) {
                Text("© 2025 Edd Mann")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Let your voice do the work.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Project Link
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
        .frame(maxWidth: .infinity)
    }

    // MARK: - Service Selection

    private var serviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $settings.selectedServiceIdentifier) {
                Text("Local WhisperKit").tag("whisperkit")
                Text("OpenAI Transcription").tag("openai")
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Text(serviceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var serviceDescription: String {
        switch settings.selectedServiceIdentifier {
        case "openai":
            return "Cloud transcription via OpenAI API. Supports Whisper and GPT-4o models. Requires internet and API key."
        case "whisperkit":
            return "Local transcription using CoreML. Audio never leaves your device. No API key needed."
        default:
            return ""
        }
    }

    // MARK: - OpenAI Section

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model Selection
            HStack {
                Text("Model")
                    .font(.subheadline)

                Spacer()

                Picker("Model", selection: $settings.openAIModel) {
                    ForEach(OpenAIService.Model.allCases, id: \.self) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Text(settings.openAIModel.description)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            // API Key
            HStack {
                Text("API Key")
                    .font(.subheadline)

                SecureField("sk-...", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if !openAIKey.isEmpty {
                    Button(action: {
                        clearOpenAIKey()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Clear API key")
                }

                Button("Save") {
                    saveOpenAIKey()
                }
                .disabled(openAIKey.isEmpty)
                .controlSize(.small)
            }

            HStack {
                if showingAPIKeySaved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()

                Link("Get API key →",
                     destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }

            Divider()
                .padding(.vertical, 4)

            // Post-Processing
            Toggle("AI Post-Processing", isOn: $settings.openAIPostProcessEnabled)
                .font(.subheadline)

            Text("Uses GPT-4o-mini to improve formatting and punctuation.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical, 4)

            // Cloud notice
            HStack(spacing: 6) {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.blue)
                Text("Requires internet connection")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - WhisperKit Section

    private var whisperKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Model Selection Row with status
            HStack {
                Text("Model")
                    .font(.subheadline)

                Spacer()

                Picker("Model", selection: $settings.whisperKitModel) {
                    ForEach(WhisperKitService.Model.allCases, id: \.self) { model in
                        Text("\(model.displayName) (\(model.approximateSize))").tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                if downloadingModels.contains(settings.whisperKitModel) {
                    ProgressView()
                        .controlSize(.small)
                } else if downloadedModels.contains(settings.whisperKitModel) {
                    Button(action: {
                        deleteModel(settings.whisperKitModel)
                    }) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete model")
                } else {
                    Button("Download") {
                        downloadModel(settings.whisperKitModel)
                    }
                    .controlSize(.small)
                }
            }

            if let error = downloadError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()
                .padding(.vertical, 4)

            // Post-Processing Toggle
            Toggle("AI Post-Processing", isOn: $settings.whisperKitPostProcessEnabled)
                .font(.subheadline)

            Text("Improves formatting and punctuation using a local AI model.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if settings.whisperKitPostProcessEnabled {
                // AI Model selection with status
                HStack {
                    Text("AI Model")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Picker("Model", selection: $settings.mlxModel) {
                        ForEach(MLXService.Model.allCases, id: \.self) { model in
                            Text("\(model.displayName) (\(model.approximateSize))").tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if downloadingMLXModels.contains(settings.mlxModel) {
                        ProgressView()
                            .controlSize(.small)
                    } else if downloadedMLXModels.contains(settings.mlxModel) {
                        Button(action: {
                            deleteMLXModel(settings.mlxModel)
                        }) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .help("Delete model")
                    } else {
                        Button("Download") {
                            downloadMLXModel(settings.mlxModel)
                        }
                        .controlSize(.small)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            // Privacy notice
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Text("100% Private & Offline")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Smart Paste Section

    private var smartPasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("Smart Paste", isOn: $settings.smartPasteEnabled)
                    .font(.subheadline)
                    .disabled(!hasAccessibilityPermission)

                Spacer()

                if hasAccessibilityPermission {
                    Label("Enabled", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button(action: {
                        appState.openAccessibilitySettings()
                    }) {
                        Label("Grant Access", systemImage: "lock.shield")
                    }
                    .controlSize(.small)
                }
            }

            Text("Automatically paste transcriptions into the previous app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Keyboard Shortcut Section

    private var keyboardShortcutSection: some View {
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
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - History Section

    private var historySection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("History Limit")
                    .font(.subheadline)
                Text("Older transcriptions are automatically removed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: $settings.historyLimit) {
                Text("10").tag(10)
                Text("25").tag(25)
                Text("50").tag(50)
                Text("100").tag(100)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 80)
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Launch at Login Section

    private var launchAtLoginSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start at Login")
                    .font(.subheadline)
                Text("Automatically launch VoiceScribe when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Settings Management

    private func loadSettings() {
        // Load OpenAI key if exists
        Task { @MainActor in
            if let key = await KeychainRepository.shared.retrieve(for: "openai") {
                openAIKey = key
            }
        }

        // Check which models are downloaded
        refreshDownloadedModels()
        refreshDownloadedMLXModels()
    }

    private func refreshDownloadedModels() {
        downloadedModels = WhisperKitService.getDownloadedModels()
    }

    private func refreshDownloadedMLXModels() {
        downloadedMLXModels = MLXService.getDownloadedModels()
    }

    private func downloadModel(_ model: WhisperKitService.Model) {
        downloadingModels.insert(model)
        downloadError = nil

        Task {
            do {
                try await WhisperKitService.downloadModel(model) { progress in
                    // Could update UI with progress here if needed
                }

                await MainActor.run {
                    downloadingModels.remove(model)
                    refreshDownloadedModels()
                }
            } catch {
                await MainActor.run {
                    downloadingModels.remove(model)
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func deleteModel(_ model: WhisperKitService.Model) {
        do {
            try WhisperKitService.deleteModel(model)
            refreshDownloadedModels()
            downloadError = nil
        } catch {
            downloadError = error.localizedDescription
        }
    }

    private func downloadMLXModel(_ model: MLXService.Model) {
        downloadingMLXModels.insert(model)
        downloadError = nil

        Task {
            do {
                try await MLXService.shared.downloadModel(model)

                await MainActor.run {
                    downloadingMLXModels.remove(model)
                    refreshDownloadedMLXModels()
                }
            } catch {
                await MainActor.run {
                    downloadingMLXModels.remove(model)
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func deleteMLXModel(_ model: MLXService.Model) {
        Task {
            do {
                try await MLXService.shared.deleteModel(model)
                await MainActor.run {
                    refreshDownloadedMLXModels()
                    downloadError = nil
                }
            } catch {
                await MainActor.run {
                    downloadError = error.localizedDescription
                }
            }
        }
    }

    private func saveOpenAIKey() {
        Task { @MainActor in
            do {
                try await KeychainRepository.shared.save(key: openAIKey, for: "openai")
                showingAPIKeySaved = true

                // Hide success message after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                showingAPIKeySaved = false
            } catch {
                logger.error("Failed to save API key: \(error.localizedDescription)")
            }
        }
    }

    private func clearOpenAIKey() {
        Task { @MainActor in
            do {
                try await KeychainRepository.shared.delete(for: "openai")
                openAIKey = ""
                showingAPIKeySaved = false
            } catch {
                logger.error("Failed to delete API key: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Permission Management

    private func checkPermissionStatus() {
        hasAccessibilityPermission = appState.hasAccessibilityPermission
    }

    private func startPermissionCheckTimer() {
        // Check permission status every 2 seconds while settings is open
        permissionCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                // Check again after sleep in case we were cancelled
                guard !Task.isCancelled else { break }
                checkPermissionStatus()
            }
        }
    }
}

#Preview {
    SettingsView(appState: AppState(), settings: SettingsStore())
}
