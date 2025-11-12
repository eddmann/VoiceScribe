# VoiceScribe - Developer Guide for Claude Code

This document provides essential context for AI development assistants (like Claude Code) and human developers working on VoiceScribe. It covers architecture, key implementation details, and common development scenarios.

## Project Overview

**VoiceScribe** is a modern macOS transcription application that allows users to record audio via a global hotkey and receive instant transcriptions using either:
- **Local WhisperKit** (on-device, Apple Silicon only, privacy-first)
- **OpenAI Transcription** (cloud-based, supports Whisper and GPT-4o models, works on Intel Macs)

Both services support optional **AI post-processing** to improve formatting, punctuation, and clarity:
- WhisperKit uses local MLX LLM models (100% private, on-device)
- OpenAI uses GPT-4o-mini API (cloud-based)

**Tech Stack:**
- Swift 6.0 with strict concurrency
- SwiftUI for declarative UI
- SwiftData for persistence
- WhisperKit for local transcription
- KeyboardShortcuts for global hotkeys
- macOS 14.0+ (Sonoma)

## Architecture

VoiceScribe follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────┐
│              UI Layer (SwiftUI)                 │
│  RecordingView, SettingsView, MenuBarController│
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│          Application Layer                      │
│  AppState (Observable State Management)         │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│            Domain Layer                         │
│  TranscriptionService Protocol, Models, Errors │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│          Services Layer                         │
│  AudioRecorder, WhisperKitService, OpenAIService│
│  MLXService, PasteSimulator, AppFocusManager    │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│       Infrastructure Layer                      │
│  KeychainManager, SwiftData Persistence         │
└─────────────────────────────────────────────────┘
```

### Design Patterns

1. **Protocol-Oriented**: `TranscriptionService` protocol allows multiple implementations
2. **Observable Pattern**: `@Observable` macro for reactive state management
3. **Dependency Injection**: Services injected into `AppState`
4. **Single Responsibility**: Each class has one clear purpose

## Key Files and Their Roles

### App Layer (`App/`)

**`VoiceScribeApp.swift`** (Entry Point)
- SwiftUI app lifecycle
- Initializes `AppState` singleton
- Sets up menu bar controller
- Configures hotkey manager
- Important: Uses `.modelContainer` for SwiftData

**`MenuBarController.swift`** (Menu Bar Management)
- Creates and manages NSStatusItem (menu bar icon)
- Builds menu with dynamic items based on app state
- Handles menu actions (Record, History, Settings, Quit)
- Updates icon based on recording state
- Manages window lifecycle for recording, settings, and history views

**`HotkeyManager.swift`** (Global Hotkey)
- Uses `KeyboardShortcuts` library
- Default: Option-Shift-Space
- Shows recording window when triggered
- Handles hotkey conflicts and permissions

### Core/Application (`Core/Application/`)

**`AppState.swift`** (Central State Manager)
- `@Observable` macro for reactive updates
- Manages recording state machine:
  - `.idle` → `.recording` → `.processing` → `.completed`/`.error` → `.idle`
- Coordinates between services
- Handles transcription workflow
- Manages error states and recovery
- Controls smart paste behavior
- Manages transcription history with automatic cleanup
- Key methods:
  - `startRecording()`: Initializes audio recording
  - `stopRecording()`: Stops recording and triggers transcription
  - `transcribeAudio(audioURL:)`: Coordinates transcription service
  - `performSmartPaste()`: Simulates paste if enabled
  - `saveToHistory()`: Saves transcription to SwiftData
  - `cleanupOldRecords()`: Maintains history limit

### Core/Domain (`Core/Domain/`)

**`TranscriptionService.swift`** (Service Protocol)
```swift
protocol TranscriptionService: AnyObject {
    var name: String { get }
    var identifier: String { get }
    var requiresAPIKey: Bool { get }
    var isAvailable: Bool { get async }

    func validateConfiguration() async throws
    func transcribe(audioURL: URL) async throws -> String
}
```
- Defines contract for transcription implementations
- Allows easy addition of new services

**`TranscriptionRecord.swift`** (SwiftData Model)
- Persistent model for history tracking
- Fields: `id`, `text`, `timestamp`, `serviceUsed`, `audioDuration`, `audioFilePath`
- Uses `@Model` macro for SwiftData integration
- Supports querying and sorting by timestamp

**`VoiceScribeError.swift`** (Error Handling)
- Comprehensive error enum
- User-friendly error messages
- Recovery suggestions for each error type
- Conforms to `LocalizedError` for UI display

**`Date+RelativeTime.swift`** (Helper Extension)
- Extension for Date type
- Provides `relativeTimeString()` method
- Returns human-readable relative times (e.g., "2 minutes ago", "3 hours ago")
- Used in history view for displaying transcription timestamps

### Services Layer (`Services/`)

**`AudioRecorder.swift`** (Audio Recording)
- Uses `AVAudioRecorder` for audio capture
- Records in `.m4a` format (AAC codec)
- Default quality: 44.1kHz, stereo
- Saves to temporary directory
- Key methods:
  - `startRecording()`: Begins audio capture
  - `stopRecording()`: Ends capture and returns file URL
  - `deleteRecording()`: Cleans up temp file

**`WhisperKitService.swift`** (Local Transcription)
- Implements `TranscriptionService` protocol
- Uses WhisperKit library with CoreML
- **Apple Silicon only** (requires CoreML optimizations)
- Models: Base, Small, Medium
- Automatic model downloading with progress
- Offline operation (no network required)
- Models stored in: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- Key features:
  - Model management (download, delete, check status)
  - Progress callbacks for UI feedback
  - Automatic model initialization
  - Offline-first design with env vars
  - Optional AI post-processing using MLXService (local LLM)
- Post-processing: Uses local MLX LLM models for enhanced formatting

**`OpenAIService.swift`** (Cloud Transcription)
- Implements `TranscriptionService` protocol
- Uses OpenAI Transcription API
- Supports Intel and Apple Silicon
- Requires API key stored in Keychain
- Models: `whisper-1` (Whisper V2), `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`
- Key features:
  - Configurable model selection
  - Multipart form upload
  - API key validation
  - Error handling for API failures
  - Network request management
  - Optional AI post-processing using GPT-4o-mini
- Post-processing: Uses GPT-4o-mini Chat API for improved formatting and clarity

**`MLXService.swift`** (Local AI Post-Processing)
- Singleton service for post-processing transcriptions
- Uses MLX framework with local LLM models
- **Apple Silicon only** (requires MLX support)
- Models: Qwen 2.5 0.5B (Fast), Llama 3.2 3B (Balanced), Phi-3.5 Mini (Quality)
- 100% private and offline (no network required)
- Models stored in: `~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/`
- Key features:
  - Model management (download, delete, check status)
  - Progress callbacks for UI feedback
  - Automatic model downloading from HuggingFace
  - Post-processing for improved punctuation, capitalization, and clarity
- Used by WhisperKitService for optional post-processing
- Post-processing prompt: Improves transcription formatting while maintaining meaning

**`PasteSimulator.swift`** (Smart Paste)
- Simulates ⌘V keyboard shortcut
- Uses CoreGraphics event synthesis
- Requires Accessibility permissions
- Checks permissions before attempting paste
- Provides helpful error messages for permission issues
- Method to open System Settings for Accessibility permissions

**`AppFocusManager.swift`** (Focus Tracking)
- Singleton service for tracking application focus
- Tracks previously active application
- Uses NSWorkspace for app switching
- Brings back previous app after transcription
- Essential for seamless smart paste workflow
- Captures focus state before showing recording window

### Core/Infrastructure (`Core/Infrastructure/`)

**`KeychainManager.swift`** (Secure Storage)
- Stores OpenAI API keys securely
- Uses macOS Keychain Services
- Service name: `com.eddmann.VoiceScribe`
- Account: `openai-api-key`
- Operations: save, retrieve, delete
- Thread-safe with proper error handling

### UI Layer (`UI/`)

**`RecordingView.swift`** (Recording Interface)
- Modern glass effect design
- Shows recording state with animations
- Displays waveform icon and status text
- Keyboard shortcuts:
  - Space: Start/stop recording
  - ESC: Cancel
- States: idle, recording, processing, error
- Progress indicators for WhisperKit downloads
- Auto-closes window after successful paste

**`SettingsView.swift`** (Settings Panel)
- Tabbed interface:
  - **Service**: Choose transcription provider
  - **Preferences**: Smart paste, hotkey, history limit
  - **About**: App info, version
- Service-specific configuration:
  - WhisperKit: Model selection, download management, AI post-processing toggle, MLX model selection
  - OpenAI: Model selection (Whisper/GPT-4o), API key input and validation, AI post-processing toggle
- Post-processing configuration:
  - WhisperKit: Enable/disable MLX post-processing, select MLX model, download MLX models
  - OpenAI: Enable/disable GPT-4o-mini post-processing
- Permission management for smart paste
- Links to System Settings for Accessibility
- History limit configuration (10/25/50/100 transcriptions)

**`HistoryView.swift`** (Transcription History)
- Displays past transcriptions with SwiftData integration
- Shows up to configured history limit (default: 25)
- Features:
  - Service badge (WhisperKit/OpenAI)
  - Audio duration display
  - Relative timestamp (e.g., "2 minutes ago")
  - Copy to clipboard functionality
  - Empty state when no transcriptions exist
- Lazy loading with ScrollView for performance
- Real-time copy feedback with animations
- Limit display shows "X of Y" transcriptions

## Critical Data Flows

### 1. Recording → Transcription → Post-Processing → Smart Paste Flow

```
User presses hotkey
    ↓
AppFocusManager captures current app
HotkeyManager shows RecordingView
    ↓
User presses Space
    ↓
AppState.startRecording()
    ↓
AudioRecorder.startRecording()
    ↓
[User speaks]
    ↓
User presses Space
    ↓
AppState.stopRecording()
    ↓
AudioRecorder.stopRecording() → audioURL
    ↓
AppState.transcribeAudio(audioURL)
    ↓
TranscriptionService.transcribe(audioURL) → text
    ↓
IF post-processing enabled:
    WhisperKit: MLXService.postProcess(text) → enhanced text
    OpenAI: OpenAIService.postProcess(text) → enhanced text
    ↓
Copy text to clipboard (NSPasteboard)
    ↓
Save to SwiftData (TranscriptionRecord)
    ↓
IF smart paste enabled:
    AppFocusManager brings back previous app
    PasteSimulator simulates ⌘V
    RecordingView auto-closes
    ↓
Auto-reset to idle after 2 seconds
```

### 2. WhisperKit Model Download Flow

```
User selects WhisperKit model in Settings
    ↓
WhisperKitService.isModelDownloadedLocally() → false
    ↓
User clicks "Download"
    ↓
WhisperKitService.downloadModel(model, progressCallback:)
    ↓
WhisperKit downloads model from HuggingFace
    ↓
Progress updates displayed in UI
    ↓
Model saved to ~/Documents/huggingface/...
    ↓
WhisperKitService.validateConfiguration() → success
```

### 3. API Key Storage Flow

```
User enters OpenAI API key in Settings
    ↓
User clicks "Save API Key"
    ↓
KeychainManager.save(apiKey)
    ↓
Keychain stores with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ↓
OpenAIService.validateConfiguration() tests key
    ↓
Makes test API call
    ↓
Success: Key is valid
```

### 4. MLX Model Download Flow

```
User enables post-processing for WhisperKit in Settings
    ↓
User selects MLX model (Qwen/Llama/Phi)
    ↓
MLXService.isModelDownloaded(model) → false
    ↓
User clicks "Download"
    ↓
MLXService.downloadModel(model, progressCallback:)
    ↓
MLXLLM.loadModel() downloads from HuggingFace
    ↓
Progress updates displayed in UI
    ↓
Model saved to ~/Library/Containers/.../Caches/models/
    ↓
MLXService validates model → success
```

## Build and Run Commands

### Building from Xcode
```bash
# Open project
open VoiceScribe.xcodeproj

# Or build from command line
xcodebuild -project VoiceScribe.xcodeproj \
  -scheme VoiceScribe \
  -configuration Debug \
  build
```

### Running Tests (when available)
```bash
xcodebuild test \
  -project VoiceScribe.xcodeproj \
  -scheme VoiceScribe \
  -destination 'platform=macOS'
```

### Building Release
```bash
xcodebuild archive \
  -project VoiceScribe.xcodeproj \
  -scheme VoiceScribe \
  -archivePath ./build/VoiceScribe.xcarchive \
  -configuration Release
```

### Using GitHub Actions
- **Build workflow**: Triggers on push/PR to main
- **Release workflow**: Manual trigger with version number
  - Run from Actions tab: Actions → Release → Run workflow
  - Enter version (e.g., `1.0.1`)
  - Creates universal binary (Intel + Apple Silicon)
  - Publishes GitHub release with ZIP

## Common Development Scenarios

### Adding a New Transcription Service

1. Create new file in `Services/` (e.g., `AzureService.swift`)
2. Implement `TranscriptionService` protocol:
   ```swift
   final class AzureService: TranscriptionService {
       let name = "Azure Speech"
       let identifier = "azure"
       let requiresAPIKey = true

       var isAvailable: Bool {
           get async { /* check config */ }
       }

       func validateConfiguration() async throws {
           // Validate API key, endpoint, etc.
       }

       func transcribe(audioURL: URL) async throws -> String {
           // Implementation
       }
   }
   ```
3. Register in `AppState.init()`:
   ```swift
   let azureService = AzureService()
   availableServices = [whisperKit, openAI, azureService]
   ```
4. Add service-specific UI in `SettingsView.swift`

### Adding a New Recording Format

1. Modify `AudioRecorder.swift`:
   ```swift
   settings = [
       AVFormatIDKey: Int(kAudioFormatMPEG4AAC), // Change format
       AVSampleRateKey: 48000.0,                 // Change sample rate
       // ...
   ]
   ```
2. Ensure transcription services support the format
3. Update file extension handling if needed

### Adding New UI State

1. Add state to `AppState.swift`:
   ```swift
   enum RecordingState {
       case idle
       case recording
       case processing
       case paused  // New state
   }
   ```
2. Update state machine logic
3. Reflect in UI (`RecordingView.swift`)

### Enabling/Disabling Post-Processing

**For WhisperKit (MLX):**
1. Toggle in Settings → Service → WhisperKit
2. Stored in `UserDefaults.standard.bool(forKey: "whisperkit_post_process_enabled")`
3. MLX model must be downloaded
4. Only available on Apple Silicon

**For OpenAI (GPT-4o-mini):**
1. Toggle in Settings → Service → OpenAI
2. Stored in `UserDefaults.standard.bool(forKey: "openai_post_process_enabled")`
3. Requires valid API key
4. Makes additional API call (~$0.01 per transcription)

### Debugging Audio Recording Issues

1. Check microphone permissions in System Settings
2. Enable AVFoundation logging:
   ```swift
   import os.log
   private let logger = Logger(subsystem: "com.eddmann.VoiceScribe",
                               category: "AudioRecorder")
   ```
3. Inspect temp file:
   ```bash
   ls -lh $(getconf DARWIN_USER_TEMP_DIR)
   ```
4. Test with AVAudioPlayer to verify file format

### Debugging WhisperKit Issues

1. Check if model exists:
   ```bash
   ls -la ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
   ```
2. Verify Apple Silicon:
   ```bash
   uname -m  # Should show "arm64"
   ```
3. Check CoreML model format:
   ```bash
   find ~/Documents/huggingface -name "*.mlmodelc"
   ```
4. Clear and re-download model if corrupted

### Debugging Smart Paste Issues

1. Check Accessibility permissions:
   - System Settings → Privacy & Security → Accessibility
   - Verify VoiceScribe is enabled
2. Test with manual paste (⌘V) first
3. Check if clipboard has content:
   ```swift
   print(NSPasteboard.general.string(forType: .string))
   ```
4. Verify previous app focus:
   ```swift
   print(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
   ```
5. Check smart paste is enabled in UserDefaults:
   ```swift
   print(UserDefaults.standard.bool(forKey: "smartPasteEnabled"))
   ```

### Debugging MLX Post-Processing Issues

1. Check if MLX is available (Apple Silicon only):
   ```bash
   uname -m  # Should show "arm64"
   ```
2. Check if MLX model is downloaded:
   ```bash
   ls -la ~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/
   ```
3. Verify post-processing is enabled:
   ```swift
   print(UserDefaults.standard.bool(forKey: "whisperkit_post_process_enabled"))
   ```
4. Check MLX model selection:
   ```swift
   print(UserDefaults.standard.string(forKey: "mlx_model"))
   ```
5. Clear and re-download model if corrupted

## Security Considerations

### API Key Storage
- **Never** hardcode API keys in code
- Use `KeychainManager` for all sensitive data
- Keys stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Keys never logged or exposed in UI (masked with `••••••`)

### Audio File Handling
- Recordings saved to temp directory
- Files automatically cleaned up after transcription
- Use `FileManager.default.temporaryDirectory`
- Never persist audio files unless explicitly requested

### Permissions
- Microphone: Required for recording
- Accessibility: Optional, only for auto-paste
- Network: Only if using OpenAI API
- Always check permissions before attempting operations

### Privacy
- WhisperKit: All processing on-device, no network
- OpenAI: Audio sent to OpenAI servers
- History: Stored locally with SwiftData
- No telemetry or analytics

## Testing Checklist

### Manual Testing

**Recording Flow:**
- [ ] Press hotkey opens window
- [ ] Space starts recording
- [ ] Space stops recording
- [ ] ESC cancels recording
- [ ] Multiple recordings work correctly
- [ ] Error handling for no microphone permission

**WhisperKit Service:**
- [ ] Model download works
- [ ] Progress updates display correctly
- [ ] Transcription accuracy acceptable
- [ ] Model switching works
- [ ] Offline operation verified
- [ ] Intel Mac shows appropriate error

**OpenAI Service:**
- [ ] API key saving works
- [ ] API key validation catches invalid keys
- [ ] Transcription returns correct text
- [ ] Network error handling works
- [ ] Works on Intel Macs

**Smart Paste:**
- [ ] Paste happens in correct app
- [ ] Clipboard contains correct text
- [ ] Permission denial shows helpful message
- [ ] Toggle in settings works
- [ ] App focus captured before recording window opens
- [ ] Previous app restored after transcription

**Post-Processing (WhisperKit + MLX):**
- [ ] MLX model download works
- [ ] Post-processing toggle enables/disables feature
- [ ] Model selection persists
- [ ] Enhanced text has improved formatting
- [ ] Works offline
- [ ] Intel Mac shows appropriate error
- [ ] Graceful fallback if model not downloaded

**Post-Processing (OpenAI + GPT-4o-mini):**
- [ ] Post-processing toggle enables/disables feature
- [ ] Enhanced text has improved formatting
- [ ] Additional API call made successfully
- [ ] Error handling for API failures
- [ ] Cost warning displayed in UI

**History View:**
- [ ] Past transcriptions display correctly
- [ ] Service badges show correct colors
- [ ] Relative timestamps update
- [ ] Copy to clipboard works
- [ ] Empty state shows when no history
- [ ] History limit respected (10/25/50/100)
- [ ] Old records cleaned up automatically

**Settings UI:**
- [ ] Service switching works
- [ ] Model selection updates correctly
- [ ] API key masked in UI
- [ ] Hotkey customization works
- [ ] About tab shows correct version
- [ ] MLX model download UI works
- [ ] Post-processing toggles work
- [ ] History limit selector works

## File Organization

```
VoiceScribe/
├── .github/
│   └── workflows/
│       ├── build.yml          # CI build workflow
│       └── release.yml        # Release automation
├── App/
│   ├── VoiceScribeApp.swift   # App entry point
│   ├── MenuBarController.swift # Menu bar UI
│   └── HotkeyManager.swift    # Global hotkey
├── Assets.xcassets/           # App icons, colors
├── Core/
│   ├── Application/
│   │   └── AppState.swift     # Central state manager
│   ├── Domain/
│   │   ├── TranscriptionService.swift  # Service protocol
│   │   ├── TranscriptionRecord.swift   # SwiftData model
│   │   ├── VoiceScribeError.swift      # Error types
│   │   └── Date+RelativeTime.swift     # Date extension
│   └── Infrastructure/
│       └── KeychainManager.swift       # Secure storage
├── Services/
│   ├── AudioRecorder.swift    # Audio capture
│   ├── WhisperKitService.swift # Local transcription
│   ├── OpenAIService.swift    # Cloud transcription
│   ├── MLXService.swift       # Local AI post-processing
│   ├── PasteSimulator.swift   # Smart paste
│   └── AppFocusManager.swift  # Focus tracking
├── UI/
│   ├── Recording/
│   │   └── RecordingView.swift # Recording interface
│   ├── Settings/
│   │   └── SettingsView.swift  # Settings panel
│   └── History/
│       └── HistoryView.swift   # History view
├── VoiceScribe.xcodeproj/     # Xcode project
├── VoiceScribe.entitlements   # App permissions
├── CLAUDE.md                  # This file
├── IMPLEMENTATION_GUIDE.md    # Technical deep-dive
├── PRODUCT_REQUIREMENTS.md    # Product vision
├── README.md                  # User documentation
├── LICENSE                    # MIT License
└── CHANGELOG.md               # Version history
```

## Useful Resources

### Apple Documentation
- [SwiftUI](https://developer.apple.com/documentation/swiftui/)
- [SwiftData](https://developer.apple.com/documentation/swiftdata)
- [AVFoundation](https://developer.apple.com/documentation/avfoundation/)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [CoreGraphics Events](https://developer.apple.com/documentation/coregraphics/quartz_event_services)

### External Libraries
- [WhisperKit](https://github.com/argmaxinc/WhisperKit) - On-device speech recognition
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global hotkeys
- [MLX](https://github.com/ml-explore/mlx) - Apple Silicon ML framework
- [MLX-Swift](https://github.com/ml-explore/mlx-swift) - Swift bindings for MLX
- [MLX-LLM](https://github.com/ml-explore/mlx-swift-examples) - LLM support for MLX

### OpenAI API
- [Whisper API Documentation](https://platform.openai.com/docs/guides/speech-to-text)
- [API Keys](https://platform.openai.com/api-keys)

---

**Last Updated:** 2025-11-12
**Swift Version:** 6.0
**macOS Target:** 14.0+

## Recent Changes (v1.0+)

- Added MLX-based local AI post-processing for WhisperKit transcriptions
- Added GPT-4o-mini post-processing for OpenAI transcriptions
- Added transcription history view with configurable limits
- Renamed "Auto-Paste" to "Smart Paste" for clarity
- Added three MLX models: Qwen 2.5 0.5B, Llama 3.2 3B, Phi-3.5 Mini
- Added history management with automatic cleanup
- Enhanced SettingsView with post-processing configuration
- Added relative time display for history timestamps
