# AGENTS.md

Guidance for AI agents working with this codebase.

## Build Commands

```bash
# Build
xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe -configuration Debug build

# Archive for release
xcodebuild archive -project VoiceScribe.xcodeproj -scheme VoiceScribe \
  -archivePath ./build/VoiceScribe.xcarchive -configuration Release
```

## Architecture

VoiceScribe is a macOS menu bar app for voice-to-text transcription via configurable global hotkey (default: ⌥⇧Space).

### Transcription Services

| Service | Type | Platform | Post-processing |
|---------|------|----------|-----------------|
| WhisperKit | Local (on-device) | Apple Silicon only | MLX LLM (local) |
| OpenAI API | Cloud | Intel + Apple Silicon | GPT-4o-mini |

### Key Components

| Component | Purpose |
|-----------|---------|
| `AppState` | Central `@Observable` state manager, recording state machine |
| `FloatingRecordBar` | Compact floating UI with waveform visualization |
| `AudioRecorder` | AVAudioRecorder wrapper (M4A format) |
| `WhisperKitService` | Local transcription via CoreML |
| `OpenAIService` | Cloud transcription via API |
| `MLXService` | Local LLM post-processing |
| `PasteSimulator` | CGEvent ⌘V simulation |
| `AppFocusManager` | Captures/restores previous app for smart paste |
| `KeychainManager` | Actor-based secure API key storage |

### Model Storage

| Model Type | Location |
|------------|----------|
| WhisperKit | `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` |
| MLX LLM | `~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/` |

### Concurrency Model

- `AppState` uses `@Observable` + `@MainActor`
- `KeychainManager` is an `actor` for thread-safe access
- Audio level monitoring at 30fps via `Task` loop
- State machine: `.idle` → `.recording` → `.processing` → `.completed`/`.error`

## Project Structure

```
VoiceScribe/
├── App/
│   ├── VoiceScribeApp.swift      # Entry point, AppDelegate, SwiftData
│   ├── MenuBarController.swift   # NSStatusItem, window lifecycle
│   └── HotkeyManager.swift       # Configurable global hotkey
├── Core/
│   ├── Application/
│   │   └── AppState.swift        # Central state manager
│   ├── Domain/
│   │   ├── TranscriptionService.swift  # Service protocol
│   │   ├── TranscriptionRecord.swift   # SwiftData @Model
│   │   ├── VoiceScribeError.swift      # Error types
│   │   └── Date+RelativeTime.swift     # Relative time formatting
│   └── Infrastructure/
│       └── KeychainManager.swift       # Secure storage (actor)
├── Services/
│   ├── AudioRecorder.swift       # Audio capture
│   ├── WhisperKitService.swift   # Local transcription
│   ├── OpenAIService.swift       # Cloud transcription
│   ├── MLXService.swift          # Local post-processing
│   ├── AppFocusManager.swift     # App focus tracking
│   └── PasteSimulator.swift      # Paste simulation
└── UI/
    ├── Recording/
    │   └── FloatingRecordBar.swift   # Recording UI with waveform
    ├── Settings/
    │   └── SettingsView.swift        # Native macOS Settings scene
    ├── Utility/
    │   └── HiddenWindowView.swift    # Lifecycle window for Settings
    └── History/
        └── HistoryView.swift         # SwiftData history browser
```

## Core Workflow

```
User presses hotkey
    ↓
AppFocusManager.capturePreviousApplication()
MenuBarController.showRecordingWindow() → FloatingRecordBar
    ↓
Space → AppState.startRecording() → AudioRecorder
    ↓
[Recording with waveform animation]
    ↓
Space → AppState.stopRecording()
    ↓
TranscriptionService.transcribe(audioURL)
    ↓
[Optional] Post-processing (MLX or GPT-4o-mini)
    ↓
Copy to NSPasteboard, save to SwiftData
    ↓
If smart paste enabled:
  AppFocusManager.restorePreviousApplication()
  PasteSimulator.simulatePaste() → ⌘V
  Close window
    ↓
Auto-reset to idle (2s)
```
