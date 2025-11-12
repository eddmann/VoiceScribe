import SwiftUI
import KeyboardShortcuts

/// Settings view for configuring transcription services
struct SettingsView: View {
    @Bindable var appState: AppState

    @State private var selectedService: String
    @State private var smartPasteEnabled: Bool = true
    @State private var openAIKey: String = ""
    @State private var selectedOpenAIModel: OpenAIService.Model = .whisper1
    @State private var selectedWhisperModel: WhisperKitService.Model = .base
    @State private var selectedMLXModel: MLXService.Model = .qwen25_0_5b
    @State private var openAIPostProcessEnabled: Bool = false
    @State private var whisperKitPostProcessEnabled: Bool = false
    @State private var showingAPIKeySaved = false
    @State private var downloadingModels: Set<WhisperKitService.Model> = []
    @State private var downloadedModels: [WhisperKitService.Model] = []
    @State private var downloadingMLXModels: Set<MLXService.Model> = []
    @State private var downloadedMLXModels: [MLXService.Model] = []
    @State private var downloadError: String?
    @State private var hasAccessibilityPermission = false
    @State private var permissionCheckTask: Task<Void, Never>?
    @AppStorage("historyLimit") private var historyLimit: Int = 25

    init(appState: AppState) {
        self.appState = appState
        let savedService = UserDefaults.standard.string(forKey: "selectedService") ?? "whisperkit"
        _selectedService = State(initialValue: savedService)
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
            .modifier(ServiceSettingsModifier(
                selectedService: $selectedService,
                selectedOpenAIModel: $selectedOpenAIModel,
                selectedWhisperModel: $selectedWhisperModel,
                selectedMLXModel: $selectedMLXModel,
                smartPasteEnabled: $smartPasteEnabled,
                openAIPostProcessEnabled: $openAIPostProcessEnabled,
                whisperKitPostProcessEnabled: $whisperKitPostProcessEnabled,
                appState: appState
            ))
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
        .frame(width: 600, height: 600)
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

                Divider()

                historySection
            }
            .padding(24)
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 0) {
            Spacer()

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

            Spacer()
                .frame(height: 24)

            // App Name
            Text("VoiceScribe")
                .font(.system(size: 28, weight: .semibold))

            Spacer()
                .frame(height: 8)

            // Version
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("Version \(version) (\(build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
                .frame(height: 32)

            // Copyright
            VStack(spacing: 8) {
                Text("© 2025 Edd Mann")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Let your voice do the work.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
                .frame(height: 32)

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

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Service Selection

    private var serviceSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcription Service")
                .font(.headline)

            Picker("Service", selection: $selectedService) {
                Text("Local WhisperKit").tag("whisperkit")
                Text("OpenAI Transcription").tag("openai")
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
            Text("OpenAI Configuration")
                .font(.headline)

            // Model Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Model")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Model", selection: $selectedOpenAIModel) {
                    ForEach(OpenAIService.Model.allCases, id: \.self) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                        }
                        .tag(model)
                    }
                }
                .pickerStyle(.menu)

                Text(selectedOpenAIModel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // API Key
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
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
                }

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

            // Post-Processing
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable AI Post-Processing", isOn: $openAIPostProcessEnabled)
                    .font(.subheadline)

                Text("Uses GPT-4o-mini AI to improve transcription formatting, punctuation, and clarity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .foregroundStyle(.orange)
                    Text("Requires additional API call (~$0.01 per transcription)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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

            // Model Configuration (merged: Model Size + Downloaded Models)
            VStack(alignment: .leading, spacing: 12) {
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

                Divider()

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

            // Post-Processing
            mlxPostProcessingSection
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

                Button(action: {
                    deleteModel(model)
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete model")
            } else {
                Button("Download") {
                    downloadModel(model)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - MLX Post-Processing Section

    private var mlxPostProcessingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable AI Post-Processing", isOn: $whisperKitPostProcessEnabled)
                .font(.subheadline)

            Text("Improves transcription formatting and punctuation using a local AI model (LLM).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if whisperKitPostProcessEnabled {
                Divider()
                mlxModelSelectionView
                Divider()
                mlxDownloadedModelsView

                Divider()

                // Important notice
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                        Text("100% Private & Offline")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                    Text("All AI processing happens on your Mac. No data sent to any server.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var mlxModelSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local AI Model")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Model", selection: $selectedMLXModel) {
                ForEach(MLXService.Model.allCases, id: \.self) { model in
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

            Text(selectedMLXModel.description)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var mlxDownloadedModelsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Downloaded Models")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(MLXService.Model.allCases, id: \.self) { model in
                mlxModelRow(for: model)
            }
        }
    }

    @ViewBuilder
    private func mlxModelRow(for model: MLXService.Model) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayName)
                    .font(.subheadline)
                Text(model.approximateSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if downloadingMLXModels.contains(model) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if downloadedMLXModels.contains(model) {
                Label("Downloaded", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                Button(action: {
                    deleteMLXModel(model)
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .help("Delete model")
            } else {
                Button("Download") {
                    downloadMLXModel(model)
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

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Toggle Recording:")
                        .font(.subheadline)
                    Text("Default: ⌥⇧Space (Option-Shift-Space)")
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Number of transcriptions to keep:")
                        .font(.subheadline)
                    Text("Older transcriptions will be removed from the history view")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $historyLimit) {
                    Text("10").tag(10)
                    Text("25").tag(25)
                    Text("50").tag(50)
                    Text("100").tag(100)
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }
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

        // Load saved OpenAI model preference
        if let savedModel = UserDefaults.standard.string(forKey: "openai_model"),
           let model = OpenAIService.Model(rawValue: savedModel) {
            selectedOpenAIModel = model
        }

        // Load saved WhisperKit model preference
        if let savedModel = UserDefaults.standard.string(forKey: "whisperkit_model"),
           let model = WhisperKitService.Model.allCases.first(where: { $0.rawValue == savedModel }) {
            selectedWhisperModel = model
        }

        // Load smart paste preference
        smartPasteEnabled = appState.smartPasteEnabled

        // Load saved MLX model preference
        if let savedModel = UserDefaults.standard.string(forKey: "mlx_model"),
           let model = MLXService.Model(rawValue: savedModel) {
            selectedMLXModel = model
        }

        // Load post-processing preferences
        openAIPostProcessEnabled = UserDefaults.standard.bool(forKey: "openai_post_process_enabled")
        whisperKitPostProcessEnabled = UserDefaults.standard.bool(forKey: "whisperkit_post_process_enabled")

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
                try await MLXService.shared.downloadModel(model) { progress in
                    // Could update UI with progress here if needed
                }

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
        do {
            try MLXService.shared.deleteModel(model)
            refreshDownloadedMLXModels()
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

    private func clearOpenAIKey() {
        Task {
            do {
                try await KeychainManager.shared.delete(for: "openai")
                await MainActor.run {
                    openAIKey = ""
                    showingAPIKeySaved = false
                }
            } catch {
                print("Failed to delete API key: \(error)")
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

// MARK: - View Modifiers

struct ServiceSettingsModifier: ViewModifier {
    @Binding var selectedService: String
    @Binding var selectedOpenAIModel: OpenAIService.Model
    @Binding var selectedWhisperModel: WhisperKitService.Model
    @Binding var selectedMLXModel: MLXService.Model
    @Binding var smartPasteEnabled: Bool
    @Binding var openAIPostProcessEnabled: Bool
    @Binding var whisperKitPostProcessEnabled: Bool
    let appState: AppState

    func body(content: Content) -> some View {
        Group {
            content
                .onChange(of: selectedService) { _, new in
                    appState.selectedServiceIdentifier = new
                }
                .onChange(of: selectedOpenAIModel) { _, new in
                    UserDefaults.standard.set(new.rawValue, forKey: "openai_model")
                }
                .onChange(of: selectedWhisperModel) { _, new in
                    UserDefaults.standard.set(new.rawValue, forKey: "whisperkit_model")
                }
        }
        .onChange(of: selectedMLXModel) { _, new in
            UserDefaults.standard.set(new.rawValue, forKey: "mlx_model")
        }
        .onChange(of: smartPasteEnabled) { _, new in
            appState.smartPasteEnabled = new
        }
        .onChange(of: openAIPostProcessEnabled) { _, new in
            UserDefaults.standard.set(new, forKey: "openai_post_process_enabled")
        }
        .onChange(of: whisperKitPostProcessEnabled) { _, new in
            UserDefaults.standard.set(new, forKey: "whisperkit_post_process_enabled")
        }
    }
}
