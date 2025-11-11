# VoiceScribe - Implementation Guide

This comprehensive technical document covers the complete architecture, implementation details, algorithms, and testing strategy for VoiceScribe. It serves as the definitive reference for developers working on or extending the application.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)
3. [Core Components](#core-components)
4. [Data Layer](#data-layer)
5. [Security Implementation](#security-implementation)
6. [User Interface](#user-interface)
7. [Key Algorithms](#key-algorithms)
8. [Configuration & Setup](#configuration--setup)
9. [Testing Strategy](#testing-strategy)
10. [Known Issues & Limitations](#known-issues--limitations)
11. [Future Work](#future-work)
12. [Debugging Tips](#debugging-tips)

---

## Architecture Overview

VoiceScribe follows **Clean Architecture** principles with clear separation between layers:

### Layer Responsibilities

```
┌────────────────────────────────────────────────────────────┐
│                     UI Layer                               │
│  - SwiftUI Views (RecordingView, SettingsView)           │
│  - AppKit Controllers (MenuBarController)                 │
│  - User interaction handling                              │
│  - View state management                                  │
└────────────────────┬───────────────────────────────────────┘
                     │ Observes state changes
                     │ Dispatches user actions
┌────────────────────▼───────────────────────────────────────┐
│               Application Layer                            │
│  - AppState (@Observable)                                 │
│  - Business logic orchestration                           │
│  - State machine management                               │
│  - Service coordination                                   │
└────────────────────┬───────────────────────────────────────┘
                     │ Uses protocols
                     │ Coordinates services
┌────────────────────▼───────────────────────────────────────┐
│                  Domain Layer                              │
│  - TranscriptionService protocol                          │
│  - Domain models (TranscriptionRecord)                    │
│  - Error types (VoiceScribeError)                         │
│  - Business rules and contracts                           │
└────────────────────┬───────────────────────────────────────┘
                     │ Implemented by
                     │ Used by domain
┌────────────────────▼───────────────────────────────────────┐
│                 Services Layer                             │
│  - AudioRecorder (AVFoundation)                           │
│  - WhisperKitService (CoreML transcription)               │
│  - OpenAIService (API transcription & enhancement)        │
│  - MLXService (Local AI enhancement)                      │
│  - PasteSimulator (CGEvent simulation)                    │
│  - AppFocusManager (NSWorkspace)                          │
└────────────────────┬───────────────────────────────────────┘
                     │ Uses infrastructure
                     │ Accesses external systems
┌────────────────────▼───────────────────────────────────────┐
│              Infrastructure Layer                          │
│  - KeychainManager (Security framework)                   │
│  - SwiftData (Persistence)                                │
│  - File system access                                     │
│  - System integration                                     │
└────────────────────────────────────────────────────────────┘
```

### Design Principles Applied

1. **Dependency Inversion**: High-level modules depend on abstractions (protocols), not concrete implementations
2. **Single Responsibility**: Each class has one reason to change
3. **Open/Closed**: Open for extension (new services), closed for modification
4. **Interface Segregation**: Small, focused protocols
5. **Separation of Concerns**: Clear boundaries between layers

---

## Technology Stack

### Core Frameworks

| Framework | Purpose | Version |
|-----------|---------|---------|
| **Swift** | Programming language | 6.0 |
| **SwiftUI** | Declarative UI framework | macOS 14.0+ |
| **SwiftData** | Data persistence | macOS 14.0+ |
| **AVFoundation** | Audio recording | macOS 14.0+ |
| **AppKit** | Menu bar integration | macOS 14.0+ |
| **CoreGraphics** | Event simulation (paste) | macOS 14.0+ |
| **Security** | Keychain access | macOS 14.0+ |
| **Foundation** | Core utilities | macOS 14.0+ |

### External Dependencies (SPM)

| Package | Purpose | Repository |
|---------|---------|------------|
| **WhisperKit** | Local speech-to-text | [argmaxinc/WhisperKit](https://github.com/argmaxinc/WhisperKit) |
| **KeyboardShortcuts** | Global hotkey registration | [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) |
| **MLX** | Apple Silicon ML framework | [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) |
| **MLXRandom** | Random number generation for MLX | [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) |
| **MLXLLM** | Large language model support | [ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) |
| **MLXLMCommon** | Common LLM utilities | [ml-explore/mlx-swift-examples](https://github.com/ml-explore/mlx-swift-examples) |

### Swift Language Features

- **Strict Concurrency**: All code is concurrency-safe
- **@Observable Macro**: Modern state management
- **async/await**: Asynchronous programming
- **Actors**: Thread-safe state isolation
- **Protocol-Oriented**: Flexible architecture
- **Value Semantics**: Immutable data structures where appropriate

---

## Core Components

### 1. VoiceScribeApp.swift

**Purpose**: Application entry point and lifecycle management

**Key Responsibilities**:
- SwiftUI app lifecycle
- Initialize singleton `AppState`
- Configure `MenuBarController`
- Set up `HotkeyManager`
- Configure SwiftData model container

**Implementation Details**:

```swift
@main
struct VoiceScribeApp: App {
    @State private var appState = AppState()
    @State private var menuBarController: MenuBarController?

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appState)
        }
        .modelContainer(for: TranscriptionRecord.self)
    }

    init() {
        // Setup menu bar
        menuBarController = MenuBarController(appState: appState)

        // Setup hotkey
        HotkeyManager.setup { [appState] in
            appState.showRecordingWindow()
        }
    }
}
```

**Critical Decisions**:
- Menu bar app (no dock icon): `LSUIElement = true` in Info.plist
- Singleton pattern for `AppState` ensures single source of truth
- SwiftData container scoped to app lifecycle

---

### 2. AppState.swift

**Purpose**: Central state management and business logic orchestration

**State Machine**:

```
     ┌──────┐
     │ Idle │ ◄─────────────────┐
     └───┬──┘                   │
         │ startRecording()     │
         ▼                      │
  ┌───────────┐                │
  │ Recording │                │
  └─────┬─────┘                │
        │ stopRecording()      │
        ▼                      │
  ┌────────────┐               │
  │ Processing │               │
  └─────┬──────┘               │
        │ transcription        │
        │ complete             │
        └──────────────────────┘
```

**Key Properties**:

```swift
@Observable
final class AppState {
    // State
    var recordingState: RecordingState = .idle
    var currentTranscription: String = ""
    var errorMessage: String?

    // Services
    var availableServices: [TranscriptionService]
    var selectedService: TranscriptionService

    // Settings
    var autoPasteEnabled: Bool
    var showRecordingWindow: Bool

    // Dependencies
    private let audioRecorder: AudioRecorder
    private let pasteSimulator: PasteSimulator
    private let appFocusManager: AppFocusManager
}
```

**Key Methods**:

1. **`startRecording()`**
   - Validates selected service
   - Requests microphone permission if needed
   - Starts `AudioRecorder`
   - Updates state to `.recording`

2. **`stopRecording()`**
   - Stops `AudioRecorder`
   - Retrieves audio file URL
   - Updates state to `.processing`
   - Triggers transcription

3. **`transcribe(audioURL:)`**
   - Calls selected service's `transcribe()` method
   - Handles progress updates (for WhisperKit)
   - Copies result to clipboard
   - Saves to SwiftData history
   - Triggers auto-paste if enabled
   - Cleans up audio file
   - Returns to `.idle` state

4. **`performAutoPaste()`**
   - Checks accessibility permissions
   - Brings back previously focused app
   - Simulates ⌘V keystroke
   - Handles permission errors gracefully

**Error Handling**:
- All errors caught and stored in `errorMessage`
- User-friendly messages with recovery suggestions
- State automatically returns to `.idle` on error
- Errors displayed in UI with dismiss action

---

### 3. AudioRecorder.swift

**Purpose**: Audio capture using AVFoundation

**Recording Settings**:

```swift
private let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),  // AAC codec
    AVSampleRateKey: 44100.0,                   // CD quality
    AVNumberOfChannelsKey: 2,                   // Stereo
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]
```

**File Management**:
- Files saved to `FileManager.default.temporaryDirectory`
- Filename format: `recording_<timestamp>.m4a`
- Automatic cleanup after transcription
- Thread-safe file operations

**Permission Handling**:
- Requests microphone permission on first use
- Graceful degradation if denied
- Clear error messages for user

**Implementation Details**:

```swift
@MainActor
final class AudioRecorder: NSObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioURL: URL?

    func startRecording() throws {
        // Request permission
        AVAudioApplication.requestRecordPermission { granted in
            guard granted else { throw VoiceScribeError.microphonePermissionDenied }
        }

        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)

        // Create recorder
        audioURL = temporaryDirectory.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        audioRecorder = try AVAudioRecorder(url: audioURL!, settings: settings)
        audioRecorder?.record()
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        return audioURL
    }

    func deleteRecording() {
        guard let url = audioURL else { return }
        try? FileManager.default.removeItem(at: url)
        audioURL = nil
    }
}
```

---

### 4. WhisperKitService.swift

**Purpose**: Local on-device transcription using CoreML

**Model Architecture**:

| Model | Size | Performance | Accuracy | Use Case |
|-------|------|-------------|----------|----------|
| **Base (Fast)** | 150 MB | Fast | Good | General use (default) |
| **Small (Balanced)** | 500 MB | Moderate | Better | Quality transcriptions |
| **Medium (Quality)** | 1.5 GB | Slow | Best | Maximum accuracy |

**Note**: The Tiny model has been removed from VoiceScribe as Base provides a better balance of speed and accuracy. Base is now the default model.

**Model Storage**:
```
~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
├── openai_whisper-base/
├── openai_whisper-small/
└── openai_whisper-medium/
```

**Key Features**:

1. **Automatic Model Download**:
   - Downloads from HuggingFace on first use
   - Progress callbacks for UI updates
   - Verifies model integrity

2. **Offline Operation**:
   - Sets environment variables to force offline mode:
     - `HF_HUB_OFFLINE=1`
     - `TRANSFORMERS_OFFLINE=1`
     - `HF_HUB_DISABLE_IMPLICIT_TOKEN=1`

3. **Model Management**:
   - List downloaded models
   - Delete unused models
   - Switch between models
   - Check available disk space

4. **Transcription Flow**:
   ```swift
   func transcribe(audioURL: URL) async throws -> String {
       // Download model if needed
       if !isModelDownloadedLocally(currentModel) {
           try await downloadModel(currentModel) { progress in
               progressCallback?(progress)
           }
       }

       // Initialize WhisperKit
       if whisperKit == nil {
           try await initializeWhisperKit()
       }

       // Transcribe
       let results = try await whisperKit!.transcribe(audioPath: audioURL.path)
       let rawText = results.map { $0.text }.joined(separator: " ")

       // Post-process if enabled (added in v1.0)
       let postProcessEnabled = UserDefaults.standard.bool(forKey: "whisperkit_post_process_enabled")
       if postProcessEnabled {
           progressCallback?("Enhancing with AI...")
           return try await mlxService.postProcess(text: rawText) { progress in
               progressCallback?(progress)
           }
       }

       return rawText
   }
   ```

5. **AI Post-Processing Integration** (New in v1.0):
   - Optional local AI enhancement using MLX models
   - Improves punctuation, capitalization, formatting
   - Fully privacy-preserving (on-device only)
   - Toggle in Settings per service
   - Graceful fallback to raw text if enhancement fails
   - See MLXService section for details

**Apple Silicon Requirement**:
- CoreML optimizations require Apple Neural Engine
- Intel Macs will receive clear error message
- Alternative: OpenAI API service

**Error Handling**:
- Network errors during download
- Insufficient disk space
- Corrupted model files
- Unsupported architecture (Intel)

---

### 5. OpenAIService.swift

**Purpose**: Cloud-based transcription and AI enhancement using OpenAI API

**Service Name**: "OpenAI Transcription" (renamed from "OpenAI Whisper" in v1.0)

**Model Options**:

| Model | API Name | Purpose | Cost | Performance |
|-------|----------|---------|------|-------------|
| **Whisper V2** | `whisper-1` | Standard transcription | $0.006/min | Fast, accurate (default) |
| **GPT-4o Transcribe** | `gpt-4o-transcribe` | Premium transcription | $0.024/min | Highest accuracy |
| **GPT-4o Mini Transcribe** | `gpt-4o-mini-transcribe` | Budget transcription | $0.0006/min | Cost-effective |

**API Configuration**:
- **Transcription Endpoint**: `https://api.openai.com/v1/audio/transcriptions`
- **Post-Processing Endpoint**: `https://api.openai.com/v1/chat/completions` (new in v1.0)
- **Format**: `multipart/form-data` (transcription), `application/json` (post-processing)
- **Authentication**: Bearer token (stored in Keychain)

**Transcription Implementation**:

```swift
func transcribe(audioURL: URL) async throws -> String {
    // Retrieve API key from Keychain
    guard let apiKey = KeychainManager.retrieve(key: "openai-api-key") else {
        throw VoiceScribeError.apiKeyNotFound
    }

    // Get selected model from UserDefaults
    let modelRawValue = UserDefaults.standard.string(forKey: "openai_model") ?? "whisper-1"
    let selectedModel = Model(rawValue: modelRawValue) ?? .whisper1

    // Create multipart request
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/transcriptions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    // Build multipart body
    let boundary = UUID().uuidString
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    var body = Data()
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n")
    body.append("Content-Type: audio/m4a\r\n\r\n")
    body.append(try Data(contentsOf: audioURL))
    body.append("\r\n")
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.append("\(selectedModel.rawValue)\r\n")
    body.append("--\(boundary)--\r\n")

    request.httpBody = body

    // Send request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Parse response
    let json = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
    let rawText = json.text

    // Post-process if enabled (added in v1.0)
    let postProcessEnabled = UserDefaults.standard.bool(forKey: "openai_post_process_enabled")
    if postProcessEnabled {
        progressCallback?("Enhancing with AI...")
        return try await postProcess(text: rawText)
    }

    return rawText
}
```

**Post-Processing Implementation** (New in v1.0):

```swift
func postProcess(text: String) async throws -> String {
    guard let apiKey = KeychainManager.retrieve(key: "openai-api-key") else {
        throw VoiceScribeError.apiKeyNotFound
    }

    // Create chat completion request for enhancement
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Build enhancement prompt
    let payload: [String: Any] = [
        "model": "gpt-4o-mini",
        "messages": [
            [
                "role": "system",
                "content": "You are a text formatting assistant. Add proper punctuation, capitalization, and formatting. Do not change the words."
            ],
            [
                "role": "user",
                "content": "Format this transcription:\n\n\(text)"
            ]
        ],
        "temperature": 0.3
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    // Send request
    let (data, _) = try await URLSession.shared.data(for: request)
    let response = try JSONDecoder().decode(ChatResponse.self, from: data)

    return response.choices.first?.message.content ?? text
}
```

**Cost Analysis** (New in v1.0):

| Operation | Model | Typical Cost |
|-----------|-------|--------------|
| Transcription only | whisper-1 | $0.006/min |
| Transcription + Post-processing | whisper-1 + gpt-4o-mini | ~$0.01/min total |
| Premium transcription | gpt-4o-transcribe | $0.024/min |

Example: A 5-minute recording with post-processing costs approximately $0.05.

**Error Handling**:
- Invalid API key (401)
- Rate limiting (429)
- Network errors
- Malformed response
- File too large (>25 MB)

**Advantages**:
- Works on Intel Macs
- No model download required
- Always latest Whisper version
- High accuracy
- **Multiple model options** for different needs
- **Optional AI post-processing** for perfect formatting
- Cost-effective option with gpt-4o-mini-transcribe

**Disadvantages**:
- Requires internet connection
- Audio sent to OpenAI servers (transcription)
- **Text sent to OpenAI servers** (post-processing)
- API costs per request (~$0.006-0.024/min transcription, +~$0.004/min post-processing)
- Privacy considerations (suitable for non-sensitive content)

---

### 6. PasteSimulator.swift

**Purpose**: Simulate ⌘V keystroke for auto-paste functionality

**Implementation**:

```swift
final class PasteSimulator {
    func paste() throws {
        // Check accessibility permission
        guard AXIsProcessTrusted() else {
            throw VoiceScribeError.accessibilityPermissionDenied
        }

        // Create ⌘V down event
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true)
        keyDown?.flags = .maskCommand

        // Create ⌘V up event
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)

        // Post events
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    func checkPermission() -> Bool {
        return AXIsProcessTrusted()
    }
}
```

**Permission Flow**:
1. User enables "Auto-paste" in Settings
2. App checks `AXIsProcessTrusted()`
3. If denied, shows link to System Settings
4. User grants permission in System Settings → Privacy & Security → Accessibility
5. App can now simulate keystrokes

**Security**:
- macOS requires explicit user permission
- Cannot be enabled programmatically
- User can revoke at any time
- Permission persists across app launches

---

### 7. KeychainManager.swift

**Purpose**: Secure storage for API keys

**Keychain Configuration**:
```swift
static let service = "com.eddmann.VoiceScribe"
static let account = "openai-api-key"
static let accessibility = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

**Operations**:

1. **Save**:
   ```swift
   static func save(apiKey: String) throws {
       let data = apiKey.data(using: .utf8)!

       let query: [String: Any] = [
           kSecClass as String: kSecClassGenericPassword,
           kSecAttrService as String: service,
           kSecAttrAccount as String: account,
           kSecValueData as String: data,
           kSecAttrAccessible as String: accessibility
       ]

       SecItemDelete(query as CFDictionary)  // Delete existing
       let status = SecItemAdd(query as CFDictionary, nil)

       guard status == errSecSuccess else {
           throw VoiceScribeError.keychainError(status)
       }
   }
   ```

2. **Retrieve**:
   ```swift
   static func retrieve() -> String? {
       let query: [String: Any] = [
           kSecClass as String: kSecClassGenericPassword,
           kSecAttrService as String: service,
           kSecAttrAccount as String: account,
           kSecReturnData as String: true
       ]

       var result: AnyObject?
       let status = SecItemCopyMatching(query as CFDictionary, &result)

       guard status == errSecSuccess,
             let data = result as? Data,
             let apiKey = String(data: data, encoding: .utf8) else {
           return nil
       }

       return apiKey
   }
   ```

3. **Delete**:
   ```swift
   static func delete() throws {
       let query: [String: Any] = [
           kSecClass as String: kSecClassGenericPassword,
           kSecAttrService as String: service,
           kSecAttrAccount as String: account
       ]

       let status = SecItemDelete(query as CFDictionary)
       guard status == errSecSuccess || status == errSecItemNotFound else {
           throw VoiceScribeError.keychainError(status)
       }
   }
   ```

**Security Properties**:
- Data encrypted by macOS
- Only accessible when device unlocked
- Tied to this device only (not synced via iCloud)
- Protected by app sandbox
- Cannot be accessed by other apps

---

### 8. MLXService.swift

**Purpose**: On-device AI post-processing for transcriptions using local LLM models

**Overview**:
MLXService provides privacy-focused text enhancement using local language models through the MLX framework. It improves punctuation, capitalization, and formatting of raw transcriptions without sending data to external servers.

**Model Architecture**:

| Model | Size | Performance | Quality | Use Case |
|-------|------|-------------|---------|----------|
| **Qwen 2.5 0.5B** | ~300 MB | Fastest | Good | Quick enhancement |
| **Llama 3.2 3B** | ~1.8 GB | Balanced | Better | General use |
| **Phi-3.5 Mini** | ~2.4 GB | Slower | Best | Maximum quality |

**Model Storage**:
```
~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/
├── mlx-community/
│   ├── Qwen2.5-0.5B-Instruct-4bit/
│   ├── Llama-3.2-3B-Instruct-4bit/
│   └── Phi-3.5-mini-instruct-4bit/
```

**Key Features**:

1. **Privacy-First**:
   - 100% on-device processing
   - No network requests
   - No data leaves the Mac
   - Ideal for sensitive content

2. **Apple Silicon Only**:
   - Requires M1/M2/M3/M4 chip
   - Uses Metal acceleration
   - Intel Macs not supported

3. **Model Management**:
   - Automatic download on first use
   - Progress callbacks for UI
   - Model switching
   - Delete unused models

4. **Post-Processing Algorithm**:
   ```swift
   func postProcess(text: String, progressCallback: @escaping (String) -> Void) async throws -> String {
       // 1. Check if model is downloaded
       if !isModelDownloaded(currentModel) {
           progressCallback("Downloading \(currentModel.displayName)...")
           try await downloadModel(currentModel)
       }

       // 2. Load model if needed
       if llm == nil {
           progressCallback("Loading AI model...")
           try await loadModel(currentModel)
       }

       // 3. Generate enhancement prompt
       let prompt = """
       Improve the following transcription by adding proper punctuation, capitalization, and formatting.
       Do not change the words, only improve formatting.

       Transcription: \(text)

       Improved version:
       """

       // 4. Run inference
       progressCallback("Enhancing with AI...")
       let enhanced = try await llm.generate(prompt: prompt, maxTokens: text.count * 2)

       // 5. Extract and clean result
       return cleanEnhancedText(enhanced)
   }
   ```

**Implementation Details**:

```swift
@MainActor
final class MLXService {
    enum Model: String, CaseIterable {
        case qwen = "mlx-community/Qwen2.5-0.5B-Instruct-4bit"
        case llama = "mlx-community/Llama-3.2-3B-Instruct-4bit"
        case phi = "mlx-community/Phi-3.5-mini-instruct-4bit"

        var displayName: String {
            switch self {
            case .qwen: return "Qwen 2.5 0.5B (Fast)"
            case .llama: return "Llama 3.2 3B (Balanced)"
            case .phi: return "Phi-3.5 Mini (Quality)"
            }
        }

        var estimatedSize: Int64 {
            switch self {
            case .qwen: return 300_000_000      // ~300 MB
            case .llama: return 1_800_000_000   // ~1.8 GB
            case .phi: return 2_400_000_000     // ~2.4 GB
            }
        }
    }

    private var llm: LLMModel?
    private var currentModel: Model

    func downloadModel(_ model: Model) async throws {
        // Uses MLX Hub to download from Hugging Face
        let config = ModelConfiguration(id: model.rawValue)
        try await MLXHub.download(config: config)
    }

    func loadModel(_ model: Model) async throws {
        let config = ModelConfiguration(id: model.rawValue)
        llm = try await LLMModel.load(config: config)
        currentModel = model
    }

    func isModelDownloaded(_ model: Model) -> Bool {
        let modelPath = cacheDirectory.appendingPathComponent(model.rawValue)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }
}
```

**Integration with WhisperKit**:
When post-processing is enabled for WhisperKit:
```swift
// In WhisperKitService.swift
func transcribe(audioURL: URL) async throws -> String {
    // 1. Perform transcription
    let rawText = try await whisperKit.transcribe(audioPath: audioURL.path)

    // 2. Check if post-processing enabled
    let postProcessEnabled = UserDefaults.standard.bool(forKey: "whisperkit_post_process_enabled")

    if postProcessEnabled {
        // 3. Enhance with MLX
        return try await mlxService.postProcess(text: rawText) { progress in
            progressCallback?(progress)
        }
    }

    return rawText
}
```

**Error Handling**:
- **Model Download Failure**: Network issues, disk space
- **Model Load Failure**: Corrupted files, incompatible version
- **Inference Failure**: Out of memory, model error
- **Graceful Fallback**: Returns original text if enhancement fails

**Performance Characteristics**:

| Model | Load Time | Enhancement Time (100 words) | Memory Usage |
|-------|-----------|------------------------------|--------------|
| Qwen 2.5 0.5B | ~2s | ~3s | ~800 MB |
| Llama 3.2 3B | ~4s | ~8s | ~4 GB |
| Phi-3.5 Mini | ~5s | ~12s | ~5 GB |

**Privacy Benefits**:
- No API keys required
- No internet connection needed (after download)
- No data sent to external servers
- Ideal for:
  - Lawyers with client confidentiality
  - Doctors with patient privacy (HIPAA)
  - Journalists with source protection
  - Anyone with sensitive information

---

## Data Layer

### SwiftData Model: TranscriptionRecord

**Schema**:

```swift
@Model
final class TranscriptionRecord {
    @Attribute(.unique) var id: UUID
    var text: String
    var timestamp: Date  // Changed from 'date' in v1.0
    var serviceUsed: String  // Changed from 'service' in v1.0
    var audioDuration: TimeInterval?  // Changed from 'duration' in v1.0
    var audioFilePath: String?  // New in v1.0 (optional, for future playback)

    init(text: String, serviceUsed: String, audioDuration: TimeInterval? = nil) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.serviceUsed = serviceUsed
        self.audioDuration = audioDuration
        self.audioFilePath = nil
    }
}
```

**Field Changes in v1.0**:
- `date` → `timestamp`: More descriptive name
- `service` → `serviceUsed`: Clarifies this is the service that was used
- `duration` → `audioDuration`: Distinguishes from processing duration
- Added `audioFilePath`: For future audio playback feature

**Persistence**:
- Automatic SQLite backing store
- Location: `~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Application Support/default.store`
- No manual migration needed (SwiftData handles it)

**Queries**:

```swift
// Fetch all records, newest first
@Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
var records: [TranscriptionRecord]

// Fetch records for specific service
@Query(filter: #Predicate<TranscriptionRecord> { record in
    record.serviceUsed == "whisperkit"
}, sort: \TranscriptionRecord.timestamp, order: .reverse)
var whisperKitRecords: [TranscriptionRecord]

// Search by text content
@Query(filter: #Predicate<TranscriptionRecord> { record in
    record.text.localizedStandardContains(searchText)
})
var searchResults: [TranscriptionRecord]

// Limit to most recent N records (for history limit feature)
@Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
var limitedRecords: [TranscriptionRecord]
// In view: limitedRecords.prefix(historyLimit)
```

**Future Enhancements**:
- Add `appBundleID` to track source app
- Add tags for organization
- Add favorites/starred
- Export functionality

---

### Date Extension: RelativeTime

**Purpose**: Human-readable timestamp formatting for History UI

**Implementation** (New in v1.0):

```swift
extension Date {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
```

**Usage**:
```swift
// In HistoryView
Text(record.timestamp.relativeTime)
// Output examples:
// - "2 minutes ago"
// - "1 hour ago"
// - "Yesterday"
// - "Last week"
// - "Jan 15, 2025" (for older dates)
```

**Benefits**:
- More user-friendly than absolute timestamps
- Automatically updates as time passes
- Localized to user's language
- Standard iOS/macOS formatting

---

## Security Implementation

### Threat Model

**Assets to Protect**:
1. OpenAI API keys
2. Audio recordings (user speech)
3. Transcription text (potentially sensitive)
4. User privacy

**Threats**:
1. API key theft by malicious apps
2. Audio file leakage
3. Transcription history exposure
4. Network eavesdropping
5. Unauthorized clipboard access

### Mitigations

| Threat | Mitigation | Implementation |
|--------|------------|----------------|
| API key theft | Keychain storage | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Audio file leakage | Temp directory + immediate cleanup | `FileManager.temporaryDirectory`, delete after transcription |
| History exposure | App sandbox + file permissions | macOS sandbox restricts access |
| Network eavesdropping | HTTPS only | OpenAI API uses TLS 1.2+ |
| Clipboard snooping | No mitigation needed | macOS clipboard is shared by design |

### Privacy Design

1. **Local-First Option**: WhisperKit keeps all data on-device
2. **No Telemetry**: Zero analytics or crash reporting
3. **No Logging of Sensitive Data**: Audio content never logged
4. **User Control**: Clear choice between local and cloud
5. **Transparency**: README explains data handling

### Audit Logging

Logging philosophy:
- **Log**: State transitions, errors, configuration changes
- **Don't Log**: Audio content, transcription text, API keys

Example logging:
```swift
logger.info("Starting recording")  // ✅ OK
logger.info("Transcription complete: \(text.count) characters")  // ✅ OK
logger.info("Transcription: \(text)")  // ❌ NO - exposes content
logger.info("API Key: \(apiKey)")  // ❌ NO - exposes secrets
```

---

## User Interface

### 1. RecordingView

**Layout**:
```
┌─────────────────────────────┐
│   🎙️                        │  (App Icon)
│                             │
│   Ready to record...        │  (Status Text)
│                             │
│   Press Space to start      │  (Instructions)
│                             │
│   ━━━━━━━━━━━━━━━━━━━━━   │  (Progress Bar - if processing)
│                             │
└─────────────────────────────┘
```

**Glass Effect**:
- `.ultraThinMaterial` background
- Subtle border with `.quaternary` color
- Shadow for depth
- Blur effect for macOS style

**States**:

1. **Idle**:
   - Icon: Static microphone
   - Text: "Ready to record..."
   - Instructions: "Press Space to start"

2. **Recording**:
   - Icon: Animated pulsing circle
   - Text: "Recording..."
   - Instructions: "Press Space to stop"

3. **Processing**:
   - Icon: Loading spinner
   - Text: "Processing..." or model download progress
   - Progress bar visible

4. **Success**:
   - Icon: Checkmark
   - Text: "Copied to clipboard!"
   - Auto-closes after 1 second

5. **Error**:
   - Icon: Warning symbol
   - Text: Error message
   - Button: "Dismiss"

**Keyboard Shortcuts**:
- `Space`: Start/stop recording
- `Esc`: Cancel and close window

**Animations**:
- Fade in on appear
- Pulsing animation during recording
- Smooth transitions between states
- Spring animation for auto-close

---

### 2. SettingsView

**Tab Structure**:

```
┌─────────────────────────────────────────┐
│  Service | Preferences | About          │
├─────────────────────────────────────────┤
│                                         │
│  [Service-specific content]             │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

**Service Tab**:

*When WhisperKit selected:*
- Model picker (Tiny/Base/Small/Medium)
- Model size and description
- Download status indicator
- Download/Delete buttons
- Performance notes

*When OpenAI selected:*
- API key secure text field (masked)
- Save/Clear buttons
- Validation status
- Link to get API key

**Preferences Tab**:
- Auto-paste toggle
- Accessibility permission status
- Link to System Settings
- Global hotkey customization (future)

**About Tab**:
- App name and version
- Copyright notice
- License (MIT)
- Links to GitHub repo
- Credits for dependencies

---

### 3. MenuBarController

**Menu Structure**:

```
┌─────────────────────────┐
│ 🎙️ VoiceScribe         │
├─────────────────────────┤
│ Record...          ⌥⇧␣  │  (Triggers recording)
├─────────────────────────┤
│ Last: "Hello world"     │  (Recent transcription)
│ ➜ Copy Again            │
│ ➜ Delete                │
├─────────────────────────┤
│ Settings...          ⌘, │
│ History...              │
├─────────────────────────┤
│ Quit VoiceScribe     ⌘Q │
└─────────────────────────┘
```

**Dynamic Updates**:
- Menu bar icon changes during recording (animated)
- "Last" item shows most recent transcription (truncated)
- Grayed out when no history

---

### 4. HistoryView

**Purpose**: Full-window interface for viewing and managing transcription history

**Layout** (New in v1.0):

```
┌──────────────────────────────────────────────────────┐
│  History                                    ⌘H       │
│  ────────────────────────────────────────────────    │
│                                                      │
│  Search: [_________________________]  🔍            │
│                                                      │
│  History Limit: [ 10 ▼ 25 ▼ 50 ▼ 100 ▼ ]          │
│                                                      │
│  ┌────────────────────────────────────────────┐     │
│  │ 🟢 WhisperKit    "Hello world..."    2m ago│     │
│  │ Duration: 5.2s                              │     │
│  │ [Click to copy again]                       │     │
│  ├────────────────────────────────────────────┤     │
│  │ 🔵 OpenAI       "Testing transcr..." 1h ago│     │
│  │ Duration: 3.1s                              │     │
│  │ [Click to copy again]                       │     │
│  └────────────────────────────────────────────┘     │
│                                                      │
│  Showing 25 of 147 transcriptions                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Key Features**:

1. **Service Badges**:
   - WhisperKit: Green circle 🟢
   - OpenAI: Blue circle 🔵
   - Color-coded for quick identification

2. **Configurable Limits**:
   - Options: 10, 25, 50, 100 records
   - Saves preference to UserDefaults
   - Automatically deletes oldest records beyond limit
   - Prevents database bloat

3. **Click-to-Copy**:
   - Click anywhere on a row to copy text again
   - Haptic feedback on copy (if available)
   - Toast notification: "Copied to clipboard"

4. **Search Functionality**:
   - Real-time text search
   - Searches through all transcription text
   - Updates as user types
   - Case-insensitive

5. **Empty State**:
   ```
   ┌──────────────────────────────┐
   │                              │
   │       🎙️                     │
   │                              │
   │   No transcriptions yet      │
   │                              │
   │   Press ⌥⇧␣ to start        │
   │   recording                  │
   │                              │
   └──────────────────────────────┘
   ```

**Implementation**:

```swift
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TranscriptionRecord.timestamp, order: .reverse)
    private var allRecords: [TranscriptionRecord]

    @AppStorage("history_limit") private var historyLimit: Int = 25
    @State private var searchText = ""

    var filteredRecords: [TranscriptionRecord] {
        let records = searchText.isEmpty ? allRecords :
            allRecords.filter { $0.text.localizedStandardContains(searchText) }
        return Array(records.prefix(historyLimit))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Search bar
            TextField("Search transcriptions...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            // History limit picker
            Picker("History Limit", selection: $historyLimit) {
                Text("10").tag(10)
                Text("25").tag(25)
                Text("50").tag(50)
                Text("100").tag(100)
            }
            .pickerStyle(.segmented)

            // Records list
            if filteredRecords.isEmpty {
                EmptyStateView()
            } else {
                List(filteredRecords) { record in
                    TranscriptionRow(record: record)
                        .onTapGesture {
                            copyToClipboard(record.text)
                        }
                }
            }

            // Footer
            Text("Showing \(filteredRecords.count) of \(allRecords.count) transcriptions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 600, height: 500)
        .onChange(of: historyLimit) {
            cleanupOldRecords()
        }
    }

    func cleanupOldRecords() {
        // Delete records beyond limit
        let recordsToDelete = Array(allRecords.dropFirst(historyLimit))
        for record in recordsToDelete {
            modelContext.delete(record)
        }
        try? modelContext.save()
    }
}

struct TranscriptionRow: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Service badge
                Circle()
                    .fill(serviceBadgeColor)
                    .frame(width: 12, height: 12)

                Text(record.serviceUsed.capitalized)
                    .font(.headline)

                Spacer()

                Text(record.timestamp.relativeTime)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Truncated text
            Text(record.text.prefix(100) + (record.text.count > 100 ? "..." : ""))
                .lineLimit(2)

            // Duration
            if let duration = record.audioDuration {
                Text("Duration: \(String(format: "%.1f", duration))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    var serviceBadgeColor: Color {
        switch record.serviceUsed.lowercased() {
        case "whisperkit": return .green
        case "openai": return .blue
        default: return .gray
        }
    }
}
```

**Menu Bar Integration**:
- Accessible via menu bar: "History..." (⌘H shortcut)
- Opens in new window
- Window is closable and reopenable
- State persists across sessions

**Performance Optimizations**:
- Lazy loading with SwiftData @Query
- Limit prevents excessive memory usage
- Search uses efficient predicate filtering
- Row recycling with List component

---

## Key Algorithms

### 1. Recording State Machine

```swift
enum RecordingState {
    case idle
    case recording
    case processing
}

func startRecording() {
    guard recordingState == .idle else { return }

    do {
        try audioRecorder.startRecording()
        recordingState = .recording
    } catch {
        handleError(error)
    }
}

func stopRecording() {
    guard recordingState == .recording else { return }

    guard let audioURL = audioRecorder.stopRecording() else {
        recordingState = .idle
        return
    }

    recordingState = .processing
    Task {
        await transcribe(audioURL: audioURL)
    }
}
```

**Invariants**:
- Can only start recording from `.idle`
- Can only stop recording from `.recording`
- Must be in `.processing` during transcription
- Always return to `.idle` (even on error)

---

### 2. Service Selection Algorithm

```swift
func selectBestService() -> TranscriptionService? {
    // 1. Check user's saved preference
    if let savedID = UserDefaults.standard.string(forKey: "selectedServiceID"),
       let service = availableServices.first(where: { $0.identifier == savedID }) {
        return service
    }

    // 2. Prefer WhisperKit if on Apple Silicon and model downloaded
    if let whisperKit = availableServices.first(where: { $0.identifier == "whisperkit" }),
       await whisperKit.isAvailable {
        return whisperKit
    }

    // 3. Fall back to OpenAI if API key exists
    if let openAI = availableServices.first(where: { $0.identifier == "openai" }),
       await openAI.isAvailable {
        return openAI
    }

    // 4. Return first available service
    return availableServices.first
}
```

---

### 3. Auto-Paste Flow

```swift
func performAutoPaste() async {
    // 1. Ensure clipboard has content
    guard !currentTranscription.isEmpty else { return }

    // 2. Check accessibility permission
    guard pasteSimulator.checkPermission() else {
        showAccessibilityPermissionError()
        return
    }

    // 3. Restore focus to previous app
    await appFocusManager.restorePreviousApp()

    // 4. Small delay for app switch
    try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms

    // 5. Simulate paste
    do {
        try pasteSimulator.paste()
    } catch {
        handleError(error)
    }
}
```

**Timing Critical**:
- Must wait for app switch to complete
- Too short: paste fails (wrong app)
- Too long: poor UX
- 200ms is optimal for most Macs

---

### 4. WhisperKit Model Download

```swift
func downloadModel(_ model: Model, progressCallback: @escaping (String) -> Void) async throws {
    // 1. Check disk space
    let requiredSpace = model.estimatedBytes
    let availableSpace = try getAvailableDiskSpace()
    guard availableSpace > requiredSpace * 2 else {
        throw VoiceScribeError.insufficientDiskSpace(
            required: requiredSpace,
            available: availableSpace
        )
    }

    // 2. Clear offline mode env vars (allow download)
    unsetenv("HF_HUB_OFFLINE")

    // 3. Initialize WhisperKit (triggers download)
    progressCallback("Connecting to Hugging Face...")
    let config = WhisperKitConfig(model: model.rawValue)

    progressCallback("Downloading \(model.displayName)...")
    let whisperKit = try await WhisperKit(config)

    // 4. Verify download
    guard isModelDownloadedLocally(model) else {
        throw VoiceScribeError.modelDownloadFailed(
            modelName: model.displayName,
            reason: "Model not found after download"
        )
    }

    progressCallback("Download complete!")
}
```

---

### 5. AI Post-Processing Algorithm

**Purpose**: Enhance raw transcriptions with proper formatting using AI

**Overview** (New in v1.0):
Post-processing is an optional step that improves transcription quality by adding punctuation, capitalization, and formatting. Users can choose between two modes:
- **OpenAI Mode**: Cloud-based enhancement using GPT-4o-mini
- **MLX Mode**: Local on-device enhancement using MLX models

**Decision Flow**:

```swift
func performPostProcessing(text: String, service: TranscriptionService) async throws -> String {
    // 1. Check if post-processing is enabled for this service
    let postProcessKey = "\(service.identifier)_post_process_enabled"
    guard UserDefaults.standard.bool(forKey: postProcessKey) else {
        return text  // Return raw text if disabled
    }

    // 2. Determine which post-processor to use based on service
    do {
        switch service.identifier {
        case "whisperkit":
            // Use local MLX for privacy
            return try await mlxService.postProcess(text: text) { progress in
                progressCallback?(progress)
            }

        case "openai":
            // Use OpenAI GPT-4o-mini for cloud
            return try await openAIService.postProcess(text: text)

        default:
            return text
        }
    } catch {
        // Graceful fallback: if post-processing fails, return original text
        logger.error("Post-processing failed: \(error.localizedDescription)")
        return text
    }
}
```

**OpenAI Post-Processing Flow**:

```
Raw Text
    ↓
Build system prompt: "You are a formatting assistant..."
    ↓
Build user prompt: "Format this transcription: {text}"
    ↓
Call GPT-4o-mini via chat completions API
    ↓
Extract enhanced text from response
    ↓
Return formatted text
```

**MLX Post-Processing Flow**:

```
Raw Text
    ↓
Check if model downloaded
    ├─ No → Download model with progress
    └─ Yes → Continue
    ↓
Check if model loaded
    ├─ No → Load model into memory
    └─ Yes → Continue
    ↓
Build enhancement prompt
    ↓
Run local inference (Metal acceleration)
    ↓
Extract and clean enhanced text
    ↓
Return formatted text
```

**Prompt Engineering**:

Both services use carefully crafted prompts to ensure consistent results:

```
System Prompt:
"You are a text formatting assistant. Your job is to add proper punctuation, capitalization,
and formatting to transcribed speech. Do not change any words, only improve formatting.
Be conservative with changes - only fix obvious errors."

User Prompt:
"Format this transcription:

{raw_text}

Improved version:"
```

**Graceful Fallback Strategy**:

Post-processing failures should never lose user data:

```swift
do {
    enhancedText = try await postProcess(rawText)
} catch {
    // Log error
    logger.error("Post-processing failed: \(error)")

    // Show user notification (optional)
    showNotification("Enhancement failed, using original transcription")

    // Return original text
    enhancedText = rawText
}

// Always copy to clipboard (enhanced or original)
NSPasteboard.general.setString(enhancedText, forType: .string)
```

**Performance Considerations**:

| Service | Mode | Typical Time (100 words) | Cost |
|---------|------|--------------------------|------|
| WhisperKit + MLX | Local | 3-12s (depending on model) | Free |
| OpenAI + GPT-4o-mini | Cloud | 1-2s | ~$0.004/transcription |

**User Experience**:

During post-processing, the UI shows:
1. Progress message: "Enhancing with AI..."
2. Sparkle icon (✨) to indicate AI processing
3. Progress updates from callbacks
4. Final result or fallback to original

**Configuration**:

Users control post-processing via Settings:
- Per-service toggle: "Enhance transcriptions"
- MLX model selection (if using WhisperKit)
- Clear explanation of privacy tradeoffs

**Privacy Comparison**:

| Mode | Data Sent | Privacy Level | Cost |
|------|-----------|---------------|------|
| WhisperKit + MLX | Nothing | Highest (100% local) | Free |
| OpenAI + GPT-4o-mini | Transcribed text only | Medium | ~$0.01/transcription |

**Benefits**:

- **Improved Readability**: Proper sentences with capitals and periods
- **Professional Quality**: Output ready for documentation or emails
- **Time Savings**: No manual editing needed
- **Flexibility**: Choose cloud (fast) or local (private)

---

## Configuration & Setup

### Xcode Project Configuration

**Build Settings**:
- **Deployment Target**: macOS 14.0
- **Swift Language Version**: 6.0
- **Architectures**: arm64, x86_64 (universal binary)
- **Code Signing**: Automatic (development) / Manual (release)

**Info.plist** (key settings):
```xml
<key>LSUIElement</key>
<true/>  <!-- Menu bar app, no dock icon -->

<key>NSMicrophoneUsageDescription</key>
<string>VoiceScribe needs microphone access to record audio for transcription.</string>
```

**Entitlements**:
```xml
<key>com.apple.security.app-sandbox</key>
<true/>

<key>com.apple.security.network.client</key>
<true/>  <!-- For OpenAI API -->

<key>com.apple.security.device.audio-input</key>
<true/>  <!-- For microphone -->

<key>com.apple.security.files.user-selected.read-write</key>
<true/>  <!-- For file dialogs (future) -->
```

### Swift Package Dependencies

**Package.swift equivalent**:
```swift
dependencies: [
    .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.5.0"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.11.0")
]
```

---

## Testing Strategy

### Manual Testing Checklist

**Recording Flow** (10 tests):
- [ ] Press hotkey opens recording window
- [ ] Recording window appears centered on screen
- [ ] Press Space starts recording
- [ ] Microphone permission requested on first use
- [ ] Red pulsing animation during recording
- [ ] Press Space stops recording
- [ ] ESC cancels recording and closes window
- [ ] Recording with no speech shows appropriate error
- [ ] Multiple consecutive recordings work
- [ ] Recording with WhisperKit works
- [ ] Recording with OpenAI works

**WhisperKit Service** (12 tests):
- [ ] Model selection updates UserDefaults
- [ ] Download button appears for undownloaded models
- [ ] Download progress updates in UI
- [ ] Model download completes successfully
- [ ] Downloaded model appears in file system
- [ ] Delete button appears for downloaded models
- [ ] Model deletion removes files
- [ ] Transcription with Tiny model works
- [ ] Transcription with Base model works
- [ ] Switching models mid-session works
- [ ] Offline operation works (no network)
- [ ] Intel Mac shows clear error message

**OpenAI Service** (8 tests):
- [ ] API key input is masked (shows bullets)
- [ ] Save button stores key in Keychain
- [ ] Invalid API key shows error
- [ ] Valid API key shows success
- [ ] Transcription with OpenAI works
- [ ] Network error shows helpful message
- [ ] Clear API key removes from Keychain
- [ ] Works on Intel Macs

**Auto-Paste** (8 tests):
- [ ] Toggle in settings updates UserDefaults
- [ ] Accessibility permission check works
- [ ] Link to System Settings opens correctly
- [ ] Paste happens in previously focused app
- [ ] Clipboard contains correct text before paste
- [ ] Paste works in TextEdit
- [ ] Paste works in web browsers
- [ ] Permission denial shows helpful error

**Settings UI** (10 tests):
- [ ] Settings window opens via menu or ⌘,
- [ ] Service tab shows current service
- [ ] Switching services updates selection
- [ ] Model picker shows all models
- [ ] Download status indicators accurate
- [ ] API key field masked correctly
- [ ] Preferences tab shows correct toggle states
- [ ] About tab shows correct version
- [ ] Window can be closed and reopened
- [ ] Settings persist across app restarts

**Menu Bar** (6 tests):
- [ ] Menu bar icon appears on launch
- [ ] Icon changes during recording
- [ ] Menu shows correct items
- [ ] "Last" item shows recent transcription
- [ ] "Copy Again" copies to clipboard
- [ ] Quit quits app cleanly

**History** (6 tests):
- [ ] New transcriptions saved to SwiftData
- [ ] History view shows all records
- [ ] Records sorted newest first
- [ ] Search filters records correctly
- [ ] Delete removes record
- [ ] History persists across app restarts

**Error Handling** (8 tests):
- [ ] Microphone permission denial handled
- [ ] Accessibility permission denial handled
- [ ] OpenAI API errors handled
- [ ] Network errors handled
- [ ] No audio recorded error handled
- [ ] Model not found error handled
- [ ] Disk space error handled
- [ ] All errors show user-friendly messages

---

### Unit Tests (Recommended)

**Test Target Structure**:
```
VoiceScribeTests/
├── AppStateTests.swift
├── AudioRecorderTests.swift
├── KeychainManagerTests.swift
├── OpenAIServiceTests.swift
├── WhisperKitServiceTests.swift
├── PasteSimulatorTests.swift
└── ModelTests/
    ├── TranscriptionRecordTests.swift
    └── VoiceScribeErrorTests.swift
```

**Key Test Cases**:

1. **AppState**:
   - State transitions work correctly
   - Error handling returns to idle
   - Service selection logic

2. **AudioRecorder**:
   - Recording creates file
   - Stop returns URL
   - Delete removes file

3. **KeychainManager**:
   - Save stores data
   - Retrieve returns data
   - Delete removes data
   - Non-existent key returns nil

4. **OpenAIService**:
   - API request format correct
   - Response parsing works
   - Error codes handled

5. **TranscriptionRecord**:
   - Initialization works
   - SwiftData queries work

---

## Known Issues & Limitations

### Current Limitations

1. **WhisperKit Intel Support**: No CoreML on Intel Macs
   - **Mitigation**: Clear error message, suggest OpenAI API

2. **No Hotkey Customization**: Hardcoded to Option-Shift-Space
   - **Future**: Add UI for customization

3. **No Playback**: Can't replay recorded audio
   - **Future**: Store audio files, add playback UI

4. **No Export**: Can't export history
   - **Future**: Add CSV/JSON export

5. **English Only**: No language selection
   - **Future**: Add language picker (WhisperKit supports 90+ languages)

6. **No Timestamps**: Can't see timestamps within transcription
   - **Future**: WhisperKit provides word-level timestamps

7. **No Editing**: Can't edit transcription before paste
   - **Future**: Add edit mode before paste

8. **No Cloud Sync**: History not synced across devices
   - **Future**: iCloud sync via SwiftData

### Known Bugs

1. **Permission Dialog Timing**: If microphone permission dialog appears, recording window may be hidden behind it
   - **Workaround**: User needs to manually bring recording window forward
   - **Fix**: Detect permission dialog, auto-bring-forward after approval

2. **Auto-Paste Focus Loss**: Rarely, auto-paste fails if user switches apps manually during processing
   - **Workaround**: Copy still works, user can paste manually
   - **Fix**: Lock focus during processing

---

## Future Work

### Phase 1: Core Improvements
- [ ] Unit test coverage (target: 60%)
- [ ] Customizable hotkey in UI
- [ ] Language selection for transcription
- [ ] Audio playback in history
- [ ] Export history to CSV/JSON

### Phase 2: Enhanced Features
- [ ] Edit transcription before paste
- [ ] Word-level timestamps in history
- [ ] Multiple hotkeys for different actions
- [ ] System-wide text replacement (snippets)
- [ ] Auto-correction and formatting options

### Phase 3: Advanced Features
- [ ] iCloud sync for history
- [ ] Siri Shortcuts support
- [ ] Watch app for recording
- [ ] Real-time streaming transcription
- [ ] Custom vocabulary (names, technical terms)
- [ ] Speaker diarization (identify speakers)

### Phase 4: Enterprise Features
- [ ] Team sharing (shared transcriptions)
- [ ] Admin dashboard
- [ ] Custom model training
- [ ] On-premises deployment
- [ ] HIPAA compliance mode

---

## Debugging Tips

### Logging

**View logs** (real-time):
```bash
log stream --predicate 'subsystem == "com.eddmann.VoiceScribe"' --level debug
```

**Filter by category**:
```bash
log stream --predicate 'subsystem == "com.eddmann.VoiceScribe" && category == "AudioRecorder"'
```

**Save logs to file**:
```bash
log show --predicate 'subsystem == "com.eddmann.VoiceScribe"' --last 1h > voicescribe.log
```

### Common Issues

**1. Microphone not working**:
```bash
# Check permission
tccutil reset Microphone com.eddmann.VoiceScribe

# List audio devices
system_profiler SPAudioDataType
```

**2. WhisperKit model not found**:
```bash
# Check model directory
ls -la ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/

# Verify model files
find ~/Documents/huggingface -name "*.mlmodelc"

# Check disk space
df -h ~
```

**3. OpenAI API errors**:
```bash
# Test API key manually
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# Check network connectivity
nc -zv api.openai.com 443
```

**4. Keychain issues**:
```bash
# View Keychain entry
security find-generic-password -s "com.eddmann.VoiceScribe" -a "openai-api-key"

# Delete Keychain entry
security delete-generic-password -s "com.eddmann.VoiceScribe" -a "openai-api-key"
```

**5. SwiftData database issues**:
```bash
# Find database
find ~/Library/Containers/com.eddmann.VoiceScribe -name "*.store"

# SQLite introspection
sqlite3 ~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Application\ Support/default.store
> .tables
> .schema
```

---

## Conclusion

VoiceScribe is built with modern Swift practices, clean architecture, and user privacy in mind. This implementation guide provides comprehensive coverage of the technical details. For day-to-day development, refer to `CLAUDE.md` for quicker reference.

**Next Steps**:
1. Review `PRODUCT_REQUIREMENTS.md` for product vision
2. Read `CLAUDE.md` for development workflow
3. Check `README.md` for user-facing documentation
4. Run the manual testing checklist before releases

---

**Last Updated**: 2025-01-20
**Version**: 1.0
**Author**: Edd Mann
**License**: MIT
