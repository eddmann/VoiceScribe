# VoiceScribe - Developer Guide for Claude Code

This document provides essential context for AI development assistants (like Claude Code) and human developers working on VoiceScribe. It covers architecture, key implementation details, and common development scenarios.

## Project Overview

**VoiceScribe** is a modern macOS transcription application that allows users to record audio via a global hotkey and receive instant transcriptions using either:
- **Local WhisperKit** (on-device, Apple Silicon only, privacy-first)
- **OpenAI Whisper API** (cloud-based, works on Intel Macs)

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
│  PasteSimulator, AppFocusManager                │
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
- Handles menu actions (Settings, History, Quit)
- Updates icon based on recording state

**`HotkeyManager.swift`** (Global Hotkey)
- Uses `KeyboardShortcuts` library
- Default: Option-Shift-Space
- Shows recording window when triggered
- Handles hotkey conflicts and permissions

### Core/Application (`Core/Application/`)

**`AppState.swift`** (Central State Manager)
- `@Observable` macro for reactive updates
- Manages recording state machine:
  - `.idle` → `.recording` → `.processing` → `.idle`
- Coordinates between services
- Handles transcription workflow
- Manages error states and recovery
- Controls auto-paste behavior
- Key methods:
  - `startRecording()`: Initializes audio recording
  - `stopRecording()`: Stops recording and triggers transcription
  - `transcribe(audioURL:)`: Coordinates transcription service
  - `performAutoPaste()`: Simulates paste if enabled

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
- Fields: `id`, `text`, `date`, `service`, `duration`
- Uses `@Model` macro for SwiftData integration

**`VoiceScribeError.swift`** (Error Handling)
- Comprehensive error enum
- User-friendly error messages
- Recovery suggestions for each error type
- Conforms to `LocalizedError` for UI display

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
- Models: Tiny, Base, Small, Medium
- Automatic model downloading with progress
- Offline operation (no network required)
- Models stored in: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- Key features:
  - Model management (download, delete, check status)
  - Progress callbacks for UI feedback
  - Automatic model initialization
  - Offline-first design with env vars

**`OpenAIService.swift`** (Cloud Transcription)
- Implements `TranscriptionService` protocol
- Uses OpenAI Whisper API
- Supports Intel and Apple Silicon
- Requires API key stored in Keychain
- Uses `whisper-1` model
- Key features:
  - Multipart form upload
  - API key validation
  - Error handling for API failures
  - Network request management

**`PasteSimulator.swift`** (Auto-Paste)
- Simulates ⌘V keyboard shortcut
- Uses CoreGraphics event synthesis
- Requires Accessibility permissions
- Checks permissions before attempting paste
- Provides helpful error messages for permission issues

**`AppFocusManager.swift`** (Focus Tracking)
- Tracks previously active application
- Uses NSWorkspace for app switching
- Brings back previous app after transcription
- Essential for seamless auto-paste workflow

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
  - **Preferences**: Auto-paste, hotkey
  - **About**: App info, version
- Service-specific configuration:
  - WhisperKit: Model selection, download management
  - OpenAI: API key input and validation
- Permission management for auto-paste
- Links to System Settings for Accessibility

## Critical Data Flows

### 1. Recording → Transcription → Paste Flow

```
User presses hotkey
    ↓
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
AppState.transcribe(audioURL)
    ↓
TranscriptionService.transcribe(audioURL) → text
    ↓
Copy text to clipboard (NSPasteboard)
    ↓
Save to SwiftData (TranscriptionRecord)
    ↓
IF auto-paste enabled:
    AppFocusManager brings back previous app
    PasteSimulator simulates ⌘V
    ↓
RecordingView auto-closes after 1 second
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

### Debugging Auto-Paste Issues

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

**Auto-Paste:**
- [ ] Paste happens in correct app
- [ ] Clipboard contains correct text
- [ ] Permission denial shows helpful message
- [ ] Toggle in settings works

**Settings UI:**
- [ ] Service switching works
- [ ] Model selection updates correctly
- [ ] API key masked in UI
- [ ] Hotkey customization works
- [ ] About tab shows correct version

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
│   │   └── VoiceScribeError.swift      # Error types
│   └── Infrastructure/
│       └── KeychainManager.swift       # Secure storage
├── Services/
│   ├── AudioRecorder.swift    # Audio capture
│   ├── WhisperKitService.swift # Local transcription
│   ├── OpenAIService.swift    # Cloud transcription
│   ├── PasteSimulator.swift   # Auto-paste
│   └── AppFocusManager.swift  # Focus tracking
├── UI/
│   ├── Recording/
│   │   └── RecordingView.swift # Recording interface
│   └── Settings/
│       └── SettingsView.swift  # Settings panel
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

### OpenAI API
- [Whisper API Documentation](https://platform.openai.com/docs/guides/speech-to-text)
- [API Keys](https://platform.openai.com/api-keys)

---

**Last Updated:** 2025-01-20
**Swift Version:** 6.0
**macOS Target:** 14.0+
