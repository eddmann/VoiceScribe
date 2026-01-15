# AGENTS.md

## Project Overview

macOS menu bar app for voice-to-text transcription via configurable global hotkey (default: ⌥⇧Space). Swift 6.0 with SwiftUI + AppKit, targeting macOS 14.0+. Supports local transcription (WhisperKit on Apple Silicon) and cloud transcription (OpenAI API).

## Setup

```bash
# Clone and build
git clone git@github.com:eddmann/VoiceScribe.git
cd VoiceScribe
xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe -configuration Debug build
```

No additional setup required - Swift Package Manager resolves dependencies automatically.

## Common Commands

| Task | Command |
|------|---------|
| Build (Debug) | `xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe -configuration Debug build` |
| Build (Release) | `xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe -configuration Release build` |
| Test | `xcodebuild test -project VoiceScribe.xcodeproj -scheme VoiceScribe -configuration Debug` |
| Clean | `xcodebuild -project VoiceScribe.xcodeproj -scheme VoiceScribe clean` |
| Archive | `xcodebuild archive -project VoiceScribe.xcodeproj -scheme VoiceScribe -archivePath ./build/VoiceScribe.xcarchive -configuration Release` |

## Code Conventions

**Architecture:**
- Protocol-based design with dependency injection for testability
- All external services defined as protocols in `Services/Protocols/` and `Repositories/Protocols/`
- `@MainActor` for UI state, `actor` for thread-safe services (KeychainRepository, WhisperKitService, OpenAIService)

**File Organization:**
```
VoiceScribe/
├── App/           # Entry point, AppDelegate, state management
├── Models/        # Data models, state machines, errors
├── Services/      # Business logic (transcription, audio, paste)
│   └── Protocols/ # Service contracts
├── Repositories/  # Data access (Keychain, SwiftData)
│   └── Protocols/ # Repository contracts
└── Views/         # SwiftUI components by feature
```

**Naming:**
- Test files: `*Tests.swift` in VoiceScribeTests/
- Test doubles: `*Spy.swift`, `*Stub.swift`, `*Fake.swift` in TestDoubles/
- Protocols: `*Protocol.swift` or `*Client.swift`

**State Machine:**
- Recording states: `.idle` → `.recording` → `.processing` → `.completed`/`.error`
- Defined in `RecordingState.swift`

## Tests & CI

**Test Framework:** XCTest

**Test Structure:**
- `VoiceScribeTests/` - Main test directory
- `VoiceScribeTests/TestDoubles/` - Spies, stubs, fakes for protocol implementations
- `VoiceScribeTests/TestSupport/` - Shared test utilities

**Test Naming:** `test_<what>_<condition>_<expectedResult>`
```swift
test_startRecording_setsStateToRecording
test_transcription_success_setsStateToCompleted
test_smartPaste_enabled_withPermission_pastesText
```

**CI:** Tests run on push to `main` and on all PRs (`.github/workflows/test.yml`). Release workflow is manual dispatch only.

## PR & Workflow Rules

**Commit Format:** Conventional Commits
```
<type>(<scope>): <subject>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `security`

**Scopes:** `ui`, `site`, `settings` (optional)

**Examples:**
```
feat(ui): add waveform visualization to recording bar
fix: resolve race condition in audio level monitoring
refactor: centralize settings and add transcription cancellation
test: add comprehensive test suite for AppState
```

**Branches:**
- `main` - Production branch
- `feature/*` - Feature branches

**Releases:** Semantic versioning with `v` prefix (v1.0.0). Manual workflow dispatch.

## Security & Gotchas

**Never commit:**
- API keys (stored in macOS Keychain, not in code)
- `xcuserdata/` - Xcode user settings
- `build/` or `DerivedData/` - Build artifacts

**API Key Storage:**
- Keys stored via `KeychainRepository` actor
- Service: `com.eddmann.VoiceScribe`
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

**Entitlements Required:**
- `com.apple.security.app-sandbox` - Sandboxing
- `com.apple.security.network.client` - OpenAI API
- `com.apple.security.device.audio-input` - Microphone

**Platform Constraints:**
- WhisperKit local transcription: Apple Silicon only
- OpenAI cloud transcription: Intel + Apple Silicon
- Minimum: macOS 14.0 (Sonoma)

**Key Dependencies:**
| Package | Purpose |
|---------|---------|
| WhisperKit | Local on-device speech transcription |
| KeyboardShortcuts | Global hotkey management |
| mlx-swift-examples | Local LLM post-processing |

**Model Storage Locations:**
- WhisperKit: `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`
- MLX LLM: `~/Library/Containers/com.eddmann.VoiceScribe/Data/Library/Caches/models/`
