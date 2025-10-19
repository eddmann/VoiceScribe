# VoiceScribe

Modern macOS transcription app built with Swift 6 and SwiftUI. Record audio with a global hotkey and get instant transcriptions using either local on-device processing or cloud-based AI.

## Features

- **Global Hotkey**: Quick access with Option-Shift-Space (customizable)
- **Dual Transcription Engines**:
  - **Local WhisperKit**: Privacy-focused on-device transcription using CoreML. Your audio never leaves your Mac.
  - **OpenAI Whisper API**: Cloud-based transcription with high accuracy
- **Smart Paste**: Automatically paste transcriptions into your active application
- **Menu Bar App**: Lightweight design that lives in your menu bar
- **Model Management**: Download and manage multiple WhisperKit models (Tiny, Base, Small, Medium)
- **History Tracking**: Review past transcriptions with SwiftData persistence
- **Secure Storage**: API keys stored safely in macOS Keychain

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later (for building from source)
- Apple Silicon or Intel Mac with sufficient RAM for local models:
  - Tiny model: ~40 MB RAM
  - Base model: ~150 MB RAM
  - Small model: ~500 MB RAM
  - Medium model: ~1.5 GB RAM

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/VoiceScribe.git
   cd VoiceScribe
   ```

2. Open the project in Xcode:
   ```bash
   open VoiceScribe.xcodeproj
   ```

3. Update the Development Team in Xcode:
   - Select the VoiceScribe project in the navigator
   - Under "Signing & Capabilities", select your development team

4. Build and run (⌘R)

## Usage

### First Launch

1. VoiceScribe will appear in your menu bar as a waveform icon
2. Click the icon and select "Settings" to configure your transcription service
3. Choose between:
   - **Local WhisperKit** (recommended): Download a model to get started
   - **OpenAI Whisper API**: Add your API key from [OpenAI](https://platform.openai.com/api-keys)

### Recording Audio

1. Press **Option-Shift-Space** (or your custom hotkey) to open the recording window
2. Press **Space** to start recording
3. Speak your message
4. Press **Space** again to stop recording
5. VoiceScribe will transcribe your audio and copy it to the clipboard
6. If Smart Paste is enabled, it will automatically paste into your active app

### Keyboard Shortcuts

- **Option-Shift-Space**: Toggle recording window (customizable)
- **Space**: Start/stop recording
- **ESC**: Cancel recording or close window

## Configuration

### Local WhisperKit Settings

1. Open Settings → Service tab
2. Select "Local WhisperKit"
3. Choose your preferred model size:
   - **Tiny**: Fastest, less accurate (~40 MB)
   - **Base**: Balanced performance (~150 MB)
   - **Small**: Good quality (~500 MB)
   - **Medium**: Best quality (~1.5 GB)
4. Click "Download" to install the model locally

Models are stored in `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` and work completely offline.

### OpenAI Whisper Settings

1. Open Settings → Service tab
2. Select "OpenAI Whisper API"
3. Enter your API key from [OpenAI Platform](https://platform.openai.com/api-keys)
4. Click "Save API Key"

API keys are securely stored in your macOS Keychain.

### Smart Paste

1. Open Settings → Preferences tab
2. Enable "Automatically paste after transcription"
3. Click "Open System Settings" to grant Accessibility permission
4. Find VoiceScribe in the list and toggle it ON

## Privacy

- **Local Mode**: When using WhisperKit, all audio processing happens on your device. No data is sent to any server.
- **OpenAI Mode**: Audio is sent to OpenAI's servers for transcription. Review [OpenAI's Privacy Policy](https://openai.com/policies/privacy-policy) for details.
- **API Keys**: Stored securely in macOS Keychain, never in plain text.
- **History**: Transcription history is stored locally using SwiftData.

## Architecture

VoiceScribe follows clean architecture principles:

```
VoiceScribe/
├── App/                  # Application entry point and lifecycle
├── Core/
│   ├── Application/      # App state management
│   ├── Domain/          # Business logic and models
│   └── Infrastructure/  # Keychain, persistence
├── Services/            # Transcription services, audio recording
└── UI/                  # SwiftUI views
    ├── Recording/       # Recording interface
    └── Settings/        # Settings and configuration
```

## Dependencies

VoiceScribe is built on excellent open-source libraries:

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) by Argmax, Inc. - On-device speech recognition using CoreML
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) by Sindre Sorhus - Global keyboard shortcuts for macOS

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

VoiceScribe is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

- Whisper model by OpenAI
- WhisperKit implementation by Argmax, Inc.
- KeyboardShortcuts library by Sindre Sorhus

---

Built with ❤️ using Swift 6 and SwiftUI
