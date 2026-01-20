# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-01-20

### Changed

- Release workflow now extracts version and release notes automatically from CHANGELOG.md

## [1.3.0] - 2026-01-15

### Changed

- Restructure project with protocol-based architecture and test infrastructure
- Rename README directory to docs

## [1.2.0] - 2026-01-04

### Added

- Right-click context menu with quit option
- Animated processing indicators to floating record bar

### Changed

- Improved menu bar with icons and cleaner structure

### Fixed

- Remove ellipsis from menu bar item titles

## [1.1.0] - 2026-01-01

### Added

- Compact floating record bar with waveform visualization
- Landing page with GitHub Pages deployment
- Dark mode support with theme toggle on landing page
- Homebrew tap auto-update to release workflow
- Auto-inject latest release version on landing page deploy

### Changed

- Use native macOS Settings scene with streamlined UI
- Replace verbose CLAUDE.md with concise AGENTS.md
- Use .js- prefix pattern for theme toggle

### Fixed

- Enlarge window to allow capsule shadow to render properly
- Ensure floating record bar gains keyboard focus for spacebar

## [1.0.1] - 2025-11-26

### Added

- Code signing and notarization to release workflow

## [1.0.0] - 2025-11-12

### Added

- Global hotkey recording (Option-Shift-Space, customizable)
- Dual transcription engines: WhisperKit (local, Apple Silicon) and OpenAI Transcription (cloud)
- Multiple AI models support (WhisperKit Base/Small/Medium, OpenAI Whisper V2/GPT-4o/GPT-4o Mini)
- AI-powered enhancement for punctuation, capitalization, and formatting
- Smart paste directly into active app
- Transcription history with configurable limits
- OpenAI transcription model selection
- Device-only accessibility for Keychain API key storage
- GitHub release workflow with developer documentation
- Glass effect design for recording window UI
- App branding and layout improvements in About tab
- Auto-close window on successful paste with contextual feedback

### Changed

- Modernized UI with icons replacing text buttons in settings

### Fixed

- Use auto-generated Info.plist and resolve Swift 6 concurrency issues

[1.3.1]: https://github.com/eddmann/VoiceScribe/compare/v1.3.0...v1.3.1
[1.3.0]: https://github.com/eddmann/VoiceScribe/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/eddmann/VoiceScribe/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/eddmann/VoiceScribe/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/eddmann/VoiceScribe/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/eddmann/VoiceScribe/releases/tag/v1.0.0
