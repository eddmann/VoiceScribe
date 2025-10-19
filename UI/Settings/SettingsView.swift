import SwiftUI
import KeyboardShortcuts

/// Settings view for configuring transcription services
struct SettingsView: View {
    @Bindable var appState: AppState

    @State private var selectedService: String
    @State private var smartPasteEnabled: Bool = true
    @State private var openAIKey: String = ""
    @State private var selectedWhisperModel: WhisperKitService.Model = .tiny
    @State private var showingAPIKeySaved = false
    @State private var downloadingModels: Set<WhisperKitService.Model> = []
    @State private var downloadedModels: [WhisperKitService.Model] = []
    @State private var downloadError: String?
    @State private var hasAccessibilityPermission = false
    @State private var permissionCheckTask: Task<Void, Never>?

    init(appState: AppState) {
        self.appState = appState
        let savedService = UserDefaults.standard.string(forKey: "selectedService") ?? "whisperkit"
        _selectedService = State(initialValue: savedService)
    }

    var body: some View {
        TabView {
            // Transcription Service Tab
            transcriptionServiceTab
                .tabItem {
                    Label("Service", systemImage: "waveform")
                }

            // Smart Paste & Shortcuts Tab
            smartPasteTab
                .tabItem {
                    Label("Preferences", systemImage: "slider.horizontal.3")
                }

            // About Tab
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 600)
        .onAppear {
            loadSettings()
            checkPermissionStatus()
            // Start checking permission status periodically
            startPermissionCheckTimer()
        }
        .onDisappear {
            // Immediately cancel the task to prevent accessing deallocated memory
            permissionCheckTask?.cancel()
            permissionCheckTask = nil
        }
        .onChange(of: selectedService) { _, newValue in
            appState.selectedServiceIdentifier = newValue
        }
        .onChange(of: selectedWhisperModel) { _, newValue in
            UserDefaults.standard.set(newValue.rawValue, forKey: "whisperkit_model")
        }
        .onChange(of: smartPasteEnabled) { _, newValue in
            appState.smartPasteEnabled = newValue
        }
    }

    // MARK: - Tab Views

    private var transcriptionServiceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                serviceSelectionSection

                Divider()

                // Service-specific settings
                if selectedService == "openai" {
                    openAISection
                } else if selectedService == "whisperkit" {
                    whisperKitSection
                }
            }
            .padding(24)
        }
    }

    private var smartPasteTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                smartPasteSection

                Divider()

                keyboardShortcutSection
            }
            .padding(24)
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                Spacer()
                    .frame(height: 40)

                // App Icon
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("VoiceScribe")
                        .font(.title.bold())

                    Text("Version 1.0.0")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Modern macOS transcription app built with Swift 6 and SwiftUI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    // MARK: - Service Selection

    private var serviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Service")
                .font(.headline)

            Picker("Service", selection: $selectedService) {
                Text("Local WhisperKit").tag("whisperkit")
                Text("OpenAI Whisper API").tag("openai")
            }
            .pickerStyle(.segmented)

            Text(serviceDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var serviceDescription: String {
        switch selectedService {
        case "openai":
            return "Cloud-based transcription using OpenAI's Whisper API. Requires internet and API key."
        case "whisperkit":
            return "Local transcription using CoreML. Audio never leaves your device. No API key needed."
        default:
            return ""
        }
    }

    // MARK: - OpenAI Section

    private var openAISection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OpenAI Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SecureField("sk-...", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                if showingAPIKeySaved {
                    Label("API key saved securely", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Button("Save API Key") {
                    saveOpenAIKey()
                }
                .disabled(openAIKey.isEmpty)

                Link("Get an API key from OpenAI →",
                     destination: URL(string: "https://platform.openai.com/api-keys")!)
                    .font(.caption)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - WhisperKit Section

    private var whisperKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WhisperKit Configuration")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Model Size")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $selectedWhisperModel) {
                    ForEach(WhisperKitService.Model.allCases, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                            Text(model.approximateSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)

                Text("Larger models provide better accuracy but use more memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Model Downloads
            VStack(alignment: .leading, spacing: 12) {
                Text("Downloaded Models")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(WhisperKitService.Model.allCases, id: \.self) { model in
                    modelRow(for: model)
                }

                if let error = downloadError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Models are downloaded once and stored locally for offline use.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func modelRow(for model: WhisperKitService.Model) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.subheadline)
                Text(model.approximateSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if downloadingModels.contains(model) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if downloadedModels.contains(model) {
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Button("Delete") {
                    deleteModel(model)
                }
                .font(.caption)
                .buttonStyle(.borderless)
            } else {
                Button("Download") {
                    downloadModel(model)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Smart Paste Section

    private var smartPasteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Smart Paste")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Toggle("Automatically paste after transcription", isOn: $smartPasteEnabled)

                Text("When enabled, VoiceScribe will automatically paste transcriptions into the app you were using.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Permission status
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        if hasAccessibilityPermission {
                            Label("Accessibility permission granted", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Label("Accessibility permission required", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    if !hasAccessibilityPermission {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("To enable automatic paste, you need to grant VoiceScribe accessibility permission:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("1. Click 'Open System Settings' below")
                                Text("2. Find 'VoiceScribe' in the list")
                                Text("3. Toggle it ON")
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                            Button(action: {
                                PasteSimulator.shared.openAccessibilitySettings()
                            }) {
                                Label("Open System Settings", systemImage: "gear")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Keyboard Shortcut Section

    private var keyboardShortcutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keyboard Shortcut")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
                    .padding(.vertical, 4)

                Text("Default: ⌥⇧Space (Option-Shift-Space)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Settings Management

    private func loadSettings() {
        // Load OpenAI key if exists
        Task {
            if let key = await KeychainManager.shared.retrieve(for: "openai") {
                openAIKey = key
            }
        }

        // Load saved WhisperKit model preference
        if let savedModel = UserDefaults.standard.string(forKey: "whisperkit_model"),
           let model = WhisperKitService.Model.allCases.first(where: { $0.rawValue == savedModel }) {
            selectedWhisperModel = model
        }

        // Load smart paste preference
        smartPasteEnabled = appState.smartPasteEnabled

        // Check which models are downloaded
        refreshDownloadedModels()
    }

    private func refreshDownloadedModels() {
        downloadedModels = WhisperKitService.getDownloadedModels()
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

    private func saveOpenAIKey() {
        Task {
            do {
                try await KeychainManager.shared.save(key: openAIKey, for: "openai")
                showingAPIKeySaved = true

                // Hide success message after 2 seconds
                try? await Task.sleep(for: .seconds(2))
                showingAPIKeySaved = false
            } catch {
                print("Failed to save API key: \(error)")
            }
        }
    }

    // MARK: - Permission Management

    private func checkPermissionStatus() {
        hasAccessibilityPermission = PasteSimulator.shared.hasAccessibilityPermission
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

    private func stopPermissionCheckTimer() {
        permissionCheckTask?.cancel()
        permissionCheckTask = nil
    }
}

#Preview {
    SettingsView(appState: AppState())
}
