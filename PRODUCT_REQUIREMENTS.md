# VoiceScribe - Product Requirements Document

**Version**: 1.0
**Date**: January 2025
**Author**: Edd Mann
**Status**: Active Development

---

## Executive Summary

**VoiceScribe** is a modern macOS transcription application that enables users to quickly capture spoken thoughts and convert them to text using a global hotkey. It offers both privacy-focused on-device transcription (WhisperKit) and cloud-based transcription (OpenAI Whisper API), giving users choice over their data privacy vs. convenience trade-off.

**Key Value Proposition**:
*"From thought to text in seconds, without breaking your flow."*

### Target Market
- Knowledge workers who think faster than they type
- Developers documenting code or writing comments
- Writers and content creators capturing ideas
- Accessibility users who prefer voice input
- Privacy-conscious users wanting on-device processing

### Success Metrics
- **Adoption**: 1,000 active users in first 3 months
- **Engagement**: Average 10+ transcriptions per user per week
- **Quality**: 90%+ user satisfaction with transcription accuracy
- **Performance**: <2 seconds from hotkey press to window open
- **Reliability**: <1% error rate in production

---

## Product Vision

### Mission
Empower users to capture their thoughts at the speed of speech, making voice-to-text transcription seamless, private, and accessible on macOS.

### Long-term Vision (12-24 months)
VoiceScribe becomes the go-to voice transcription tool for Mac users who value:
1. **Speed**: Instant access via global hotkey
2. **Privacy**: Local processing option
3. **Quality**: High-accuracy transcription
4. **Integration**: Works with any application
5. **Simplicity**: One-button operation

### Competitive Advantages
1. **Dual Engine**: Only tool offering both local and cloud transcription
2. **Native macOS**: Built with SwiftUI, follows platform conventions
3. **Open Source**: Transparent, community-driven development
4. **Privacy-First**: Local option for sensitive content
5. **Lightweight**: Menu bar app with minimal resource usage

---

## Target Audience

### Primary Personas

#### 1. **Developer Dave**
- **Age**: 28-45
- **Occupation**: Software engineer
- **Goals**: Document code quickly, write commit messages, capture bug descriptions
- **Pain Points**: Typing interrupts flow state, code documentation takes too long
- **Needs**: Fast, accurate transcription that works while coding
- **Usage Pattern**: 15-20 short transcriptions per day (30 seconds each)
- **Priority**: Speed > Privacy

#### 2. **Writer Wendy**
- **Age**: 25-40
- **Occupation**: Freelance writer, blogger, journalist
- **Goals**: Capture story ideas, draft articles by speaking
- **Pain Points**: Ideas come faster than typing speed, RSI from typing
- **Needs**: High accuracy, works offline, natural language processing
- **Usage Pattern**: 5-10 longer transcriptions per day (2-5 minutes each)
- **Priority**: Accuracy > Speed

#### 3. **Privacy-Conscious Pete**
- **Age**: 30-55
- **Occupation**: Lawyer, consultant, healthcare worker
- **Goals**: Transcribe sensitive content without cloud services
- **Pain Points**: Can't use Siri/Dictation due to privacy policies
- **Needs**: Guaranteed on-device processing, no data transmission
- **Usage Pattern**: 10-15 transcriptions per day (1-2 minutes each)
- **Priority**: Privacy > Everything

#### 4. **Accessibility Alice**
- **Age**: 35-60
- **Occupation**: Various (disabilities affecting typing)
- **Goals**: Use computer efficiently without extensive typing
- **Pain Points**: Physical inability or pain when typing
- **Needs**: Reliable voice input for all applications
- **Usage Pattern**: 50+ transcriptions per day (all text input)
- **Priority**: Reliability > Features

---

## Core Features

### Feature Priority Legend
- **P0**: Must-have for v1.0
- **P1**: Should-have for v1.x
- **P2**: Nice-to-have for v2.0
- **P3**: Future consideration

---

### F1: Global Hotkey Recording (P0)

**Description**: Press a keyboard shortcut anywhere in macOS to instantly open the recording window and start capturing audio.

**User Value**:
- Instant access without breaking workflow
- No need to switch apps or find menu items
- Muscle memory for frequent users

**Technical Details**:
- Default: Option-Shift-Space (⌥⇧Space)
- Customizable in settings (P1)
- Uses KeyboardShortcuts library
- Opens floating window above all apps
- Requests microphone permission on first use

**Acceptance Criteria**:
- [ ] Hotkey triggers within 100ms
- [ ] Works across all applications
- [ ] Window appears centered on active display
- [ ] Clear error if hotkey conflicts with system shortcut
- [ ] Respects Do Not Disturb mode

---

### F2: Audio Recording (P0)

**Description**: Record high-quality audio from the Mac's microphone with visual feedback.

**User Value**:
- Visual confirmation of recording state
- High-quality audio ensures accurate transcription
- Simple one-button operation

**Technical Details**:
- Uses AVFoundation (AVAudioRecorder)
- Format: AAC in M4A container
- Sample rate: 44.1 kHz
- Channels: Stereo
- Saves to temporary directory
- Auto-cleanup after transcription

**Acceptance Criteria**:
- [ ] Recording starts within 200ms of Space press
- [ ] Visual feedback (pulsing animation) during recording
- [ ] Audio level indicator (P1)
- [ ] Maximum recording duration: 10 minutes (P1)
- [ ] Handles background noise appropriately

---

### F3: Local Transcription (WhisperKit) (P0)

**Description**: On-device speech-to-text using CoreML-optimized Whisper models with optional AI enhancement.

**User Value**:
- Complete privacy - audio never leaves device
- Works offline (no internet required)
- Free (no API costs)
- Fast on Apple Silicon
- **Optional local AI post-processing** for perfect formatting (v1.0)

**Technical Details**:
- WhisperKit library from Argmax
- **3 model sizes**: Base (Fast), Small (Balanced), Medium (Quality)
- **Note**: Tiny model removed in v1.0 - Base provides better balance
- Apple Silicon only (M1+)
- Models stored in ~/Documents/huggingface/
- Automatic model download on first use
- **Optional MLX post-processing** with 3 model sizes (v1.0):
  - Qwen 2.5 0.5B (Fast) - ~300MB
  - Llama 3.2 3B (Balanced) - ~1.8GB
  - Phi-3.5 Mini (Quality) - ~2.4GB

**Acceptance Criteria**:
- [ ] Base model transcribes 60s audio in <10s on M1
- [ ] Small model transcribes 60s audio in <15s on M1
- [ ] Medium model transcribes 60s audio in <30s on M1
- [ ] Accuracy: >85% WER (Word Error Rate) for clear speech
- [ ] Works completely offline after model download
- [ ] Clear error message on Intel Macs
- [ ] **Post-processing enhances formatting** without changing words (v1.0)
- [ ] **Graceful fallback** if post-processing fails (v1.0)

---

### F4: Cloud Transcription (OpenAI API) (P0)

**Description**: High-accuracy speech-to-text using OpenAI's transcription models with optional AI enhancement.

**User Value**:
- Works on Intel Macs
- Highest accuracy available
- No model downloads required
- Always latest Whisper version
- **Multiple model options** for different needs (v1.0)
- **Optional cloud AI post-processing** for perfect formatting (v1.0)

**Technical Details**:
- Service renamed to "OpenAI Transcription" (v1.0)
- **3 model options** (v1.0):
  - whisper-1 (Whisper V2) - $0.006/min - Standard, fast (default)
  - gpt-4o-transcribe - $0.024/min - Premium accuracy
  - gpt-4o-mini-transcribe - $0.0006/min - Budget option
- HTTPS POST with multipart/form-data
- API key stored in macOS Keychain
- Max file size: 25 MB
- **Optional GPT-4o-mini post-processing** - ~$0.004/transcription (v1.0)

**Acceptance Criteria**:
- [ ] API key validation on save
- [ ] Transcription completes in <5s for 60s audio (network-dependent)
- [ ] Accuracy: >90% WER for clear speech
- [ ] Handles network errors gracefully
- [ ] Clear error messages for API issues
- [ ] **Model selection works** (v1.0)
- [ ] **Post-processing enhances formatting** without changing words (v1.0)
- [ ] **Total cost ~$0.01/min** with post-processing enabled (v1.0)

---

### F5: Smart Auto-Paste (P0)

**Description**: Automatically paste transcribed text into the previously active application.

**User Value**:
- Zero-click workflow after recording
- Seamless integration with any app
- Feels like native macOS Dictation

**Technical Details**:
- Uses CoreGraphics event simulation
- Simulates ⌘V keystroke
- Requires Accessibility permission
- 200ms delay for app focus restoration

**Acceptance Criteria**:
- [ ] Paste happens in correct application 99% of time
- [ ] Works in all standard text fields
- [ ] Clear permission instructions if denied
- [ ] Toggle on/off in settings
- [ ] Fallback: manual paste if auto-paste disabled

---

### F6: Clipboard Integration (P0)

**Description**: Copy transcribed text to system clipboard automatically.

**User Value**:
- Always have fallback if auto-paste fails
- Can paste multiple times
- Works with clipboard managers

**Technical Details**:
- Uses NSPasteboard.general
- Copies as plain text (.string type)
- Preserves existing clipboard history
- No timeout (stays until replaced)

**Acceptance Criteria**:
- [ ] Text copied immediately after transcription
- [ ] Accessible via ⌘V in any app
- [ ] Works with clipboard manager apps
- [ ] No clipboard pollution (doesn't copy errors)

---

### F7: Transcription History (P0)

**Description**: View, search, and manage past transcriptions with full UI and configurable limits.

**User Value**:
- Reference previous transcriptions
- Search for specific content
- Recover accidentally deleted text
- **Click to copy again** (v1.0)
- **Configurable history limits** prevent database bloat (v1.0)
- **Service badges** for quick identification (v1.0)

**Technical Details**:
- SwiftData for persistence
- Stores: text, timestamp, service used, audio duration, audio file path (optional)
- Sorted newest first
- Search with SwiftUI's searchable modifier
- **Full HistoryView UI** with window (v1.0):
  - Accessible via menu bar (⌘H shortcut)
  - Service badges (green for WhisperKit, blue for OpenAI)
  - Relative timestamps ("2 minutes ago")
  - Duration display
- **Configurable limits**: 10, 25, 50, or 100 records (v1.0)
- **Automatic cleanup** deletes records beyond limit (v1.0)
- **Empty state view** for new users (v1.0)

**Acceptance Criteria**:
- [ ] All transcriptions saved automatically
- [ ] History survives app restart
- [ ] Search returns results instantly
- [ ] Delete removes from history
- [ ] **Click any row to copy text to clipboard** (v1.0)
- [ ] **History limit selector works** (10/25/50/100) (v1.0)
- [ ] **Auto-cleanup enforces limit** (v1.0)
- [ ] **Service badges color-coded correctly** (v1.0)
- [ ] **Relative timestamps update** ("5 minutes ago") (v1.0)
- [ ] **Empty state shown when no history** (v1.0)

---

### F8: Model Management (P0)

**Description**: Download, switch, and delete WhisperKit models.

**User Value**:
- Choose accuracy vs. speed tradeoff
- Manage disk space
- Download models on WiFi

**Technical Details**:
- Model sizes: 40 MB (Tiny) to 1.5 GB (Medium)
- Downloaded from Hugging Face
- Progress updates during download
- Integrity verification after download

**Acceptance Criteria**:
- [ ] Download progress shown in UI
- [ ] Can cancel download mid-way (P1)
- [ ] Delete frees disk space
- [ ] Switch model without app restart
- [ ] Warns before downloading on cellular (P1)

---

### F9: Settings Panel (P0)

**Description**: Configure transcription service, preferences, and view app information.

**User Value**:
- Easy configuration without config files
- Discover features
- Manage privacy settings

**Technical Details**:
- SwiftUI window with tabs
- 3 tabs: Service, Preferences, About
- Saves to UserDefaults
- API keys to Keychain

**Acceptance Criteria**:
- [ ] Settings accessible via menu bar (⌘,)
- [ ] All settings persist across restarts
- [ ] Clear explanations for each setting
- [ ] Links to external resources (API keys, docs)

---

### F10: Menu Bar Integration (P0)

**Description**: Lightweight menu bar app with quick access to features.

**User Value**:
- Always accessible
- No dock clutter
- Quick status check

**Technical Details**:
- NSStatusItem in menu bar
- Icon changes during recording
- Menu with common actions
- No dock icon (LSUIElement = true)

**Acceptance Criteria**:
- [ ] Icon visible in menu bar
- [ ] Icon animates during recording
- [ ] Menu shows recent transcription
- [ ] Quit option available
- [ ] Memory usage <50 MB when idle

---

### F11: Error Handling (P0)

**Description**: User-friendly error messages with recovery suggestions.

**User Value**:
- Clear explanations of what went wrong
- Actionable steps to fix issues
- Reduces frustration

**Technical Details**:
- VoiceScribeError enum with LocalizedError
- Error dialog with dismiss button
- Logs errors for debugging
- Returns to idle state after error

**Acceptance Criteria**:
- [ ] All errors shown in UI (no silent failures)
- [ ] Error messages are user-friendly (no stack traces)
- [ ] Recovery suggestions included
- [ ] Errors logged for debugging
- [ ] App remains stable after errors

---

### F12: Performance Optimization (P1)

**Description**: Fast app startup, low memory usage, responsive UI.

**User Value**:
- Doesn't slow down Mac
- Quick response times
- Smooth animations

**Technical Details**:
- Lazy loading of services
- Background processing for transcription
- Main thread only for UI updates
- Instruments profiling for optimization

**Acceptance Criteria**:
- [ ] App startup <1 second
- [ ] Memory usage <100 MB during transcription
- [ ] UI animations 60 FPS
- [ ] No beach ball cursor at any time
- [ ] Battery impact: Low (per Activity Monitor)

---

### F13: AI Post-Processing (P0) **NEW in v1.0**

**Description**: Optional AI-powered enhancement of transcriptions for perfect punctuation, capitalization, and formatting.

**User Value**:
- **Professional quality output** ready for documentation or emails
- **Dual-mode**: Choose between cloud (fast) or local (private)
- **No manual editing** needed after transcription
- **Preserves original words** - only improves formatting
- **Graceful fallback** - never loses transcription if enhancement fails

**Technical Details**:
- **Two post-processing modes**:
  1. **OpenAI Mode** (for OpenAI service):
     - Uses GPT-4o-mini via chat completions API
     - Cloud-based enhancement
     - Cost: ~$0.004 per transcription (~$0.01/min total)
     - Fast: 1-2 seconds for 100 words

  2. **MLX Mode** (for WhisperKit service):
     - 100% local, privacy-preserving
     - Uses on-device LLM models (Qwen, Llama, or Phi)
     - Apple Silicon only
     - Free, but slower: 3-12 seconds for 100 words
     - Models: 300MB - 2.4GB

- **Configuration**:
  - Toggle per service in Settings
  - MLX model selection for WhisperKit
  - Clear privacy tradeoff explanations
  - Progress indicators during enhancement

- **Enhancement capabilities**:
  - Adds periods, commas, and punctuation
  - Capitalizes proper nouns and sentence starts
  - Formats into readable paragraphs
  - Preserves original words (no paraphrasing)

**Acceptance Criteria**:
- [ ] Toggle works for each service independently
- [ ] OpenAI mode enhances text in <3s for typical transcription
- [ ] MLX mode works 100% offline after model download
- [ ] Enhancement improves readability (manual evaluation)
- [ ] Original words never changed (only formatting)
- [ ] Graceful fallback returns raw text if enhancement fails
- [ ] Progress indicator shows "Enhancing with AI..." with sparkle icon
- [ ] MLX model download shows progress
- [ ] Clear error messages if enhancement fails
- [ ] Privacy explanation visible in Settings

**Privacy Comparison**:

| Mode | Data Sent | Privacy Level | Cost | Speed |
|------|-----------|---------------|------|-------|
| WhisperKit + MLX | Nothing | Highest (100% local) | Free | 3-12s |
| OpenAI + GPT-4o-mini | Text only | Medium | ~$0.004 | 1-2s |

**Target Personas**:
- **Privacy-Conscious Pete**: Uses WhisperKit + MLX for client-confidential content
- **Developer Dave**: Uses OpenAI + GPT-4o-mini for speed when documenting code
- **Writer Wendy**: Uses MLX for article drafts (privacy + quality)

---

## User Stories

### Recording Flow

**Story 1: Quick Note Capture**
```
As a developer
I want to quickly capture a thought while coding
So that I don't lose my train of thought

Acceptance:
- Press hotkey while in Xcode
- Speak idea (5-10 seconds)
- Press space to stop
- Text appears in code comment immediately
- Back in Xcode in <3 seconds total
```

**Story 2: Long-Form Dictation**
```
As a writer
I want to dictate an entire article section
So that I can draft faster than typing

Acceptance:
- Press hotkey
- Speak for 5 minutes
- See processing indicator
- Text appears in clipboard
- Paste into writing app
- Accuracy >90% for clear speech
```

**Story 3: Sensitive Content**
```
As a lawyer
I want to transcribe client notes without cloud services
So that I maintain attorney-client privilege

Acceptance:
- Select WhisperKit in settings
- Verify "Local processing" indicator
- Record client notes
- Confirm no network activity (Activity Monitor)
- Text saved only locally
```

### Configuration

**Story 4: First-Time Setup**
```
As a new user
I want to get started quickly
So that I can use the app immediately

Acceptance:
- Download and open app
- See menu bar icon
- Press default hotkey
- Grant microphone permission (one-time)
- Choose WhisperKit (no API key needed)
- Download Tiny model (quick)
- Record first transcription successfully
- Total time <3 minutes
```

**Story 5: OpenAI Setup**
```
As a user with an OpenAI API key
I want to use cloud transcription
So that I get the highest accuracy

Acceptance:
- Open Settings → Service
- Select OpenAI Whisper API
- Enter API key
- Click "Save API Key"
- See "API key valid" confirmation
- Record test transcription
- Verify accuracy is high
```

### Error Recovery

**Story 6: Permission Denied**
```
As a user who denied microphone permission
I want clear instructions to fix it
So that I can start using the app

Acceptance:
- Press hotkey
- See error: "Microphone permission denied"
- Click "Open System Settings" button
- Land directly in Privacy & Security → Microphone
- Grant permission
- Press hotkey again
- Recording works
```

**Story 7: Network Failure**
```
As a user with spotty internet
I want transcription to fail gracefully
So that I know what happened

Acceptance:
- Use OpenAI service
- Disconnect WiFi mid-transcription
- See error: "Network connection lost"
- Error suggests: "Try WhisperKit for offline use"
- Recording is not lost
- Can retry with WhisperKit
```

### AI Post-Processing (NEW in v1.0)

**Story 8: Privacy-Preserving Enhancement**
```
As a lawyer working with confidential client information
I want to improve my transcription formatting without sending data to the cloud
So that I maintain client confidentiality while getting professional results

Acceptance:
- Select WhisperKit in settings
- Enable "Enhance transcriptions" toggle
- Select MLX model (e.g., Llama 3.2 3B)
- Record client notes (3 minutes)
- See "Enhancing with AI..." progress indicator
- Receive perfectly formatted text with proper punctuation
- Confirm no network activity during enhancement (Activity Monitor)
- Text quality suitable for legal documentation
- Total time <15 seconds from stop to clipboard
```

**Story 9: Fast Cloud Enhancement**
```
As a developer documenting code quickly
I want AI-enhanced transcriptions without waiting
So that I can get back to coding faster

Acceptance:
- Select OpenAI service in settings
- Enable "Enhance transcriptions" toggle
- Record code documentation (30 seconds)
- See sparkle icon during AI enhancement
- Receive formatted text in <5 seconds total
- Text has proper capitalization and punctuation
- Paste directly into code comments
- Understand cost is ~$0.01 per transcription (acceptable)
```

**Story 10: Enhanced Accuracy for Writers**
```
As a writer drafting an article
I want my spoken thoughts formatted professionally
So that I can paste directly into my editor without manual cleanup

Acceptance:
- Use either WhisperKit or OpenAI service
- Enable post-processing
- Speak article draft (5 minutes) naturally with "um"s and pauses
- Processing shows progress updates
- Result has:
  - Proper sentence capitalization
  - Correct punctuation (periods, commas)
  - Paragraph breaks where appropriate
  - Original words preserved (no paraphrasing)
- Paste into writing app and use immediately
- Manual editing reduced by 80%
```

**Story 11: Graceful Fallback**
```
As a user with unstable internet
I want transcription to work even if AI enhancement fails
So that I never lose my spoken content

Acceptance:
- Use OpenAI service with post-processing enabled
- Record transcription (1 minute)
- Simulate network failure during enhancement step
- See error: "Enhancement failed, using original transcription"
- Transcription still copied to clipboard (raw, unenhanced)
- Can paste and use immediately
- Data not lost
- Can try again with WhisperKit + MLX (offline)
```

---

## Success Metrics

### Adoption Metrics

| Metric | Target (3 months) | Target (6 months) | Measurement |
|--------|-------------------|-------------------|-------------|
| Total Downloads | 5,000 | 15,000 | GitHub releases |
| Active Users | 1,000 | 3,000 | Telemetry opt-in (P2) |
| GitHub Stars | 100 | 500 | GitHub API |
| Reddit Mentions | 10 | 50 | Manual search |

### Engagement Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Avg. transcriptions/user/day | 10 | Telemetry (P2) |
| Daily active users (DAU) | 500 | Telemetry (P2) |
| Weekly active users (WAU) | 1,000 | Telemetry (P2) |
| Feature usage: Auto-paste | 60% | Telemetry (P2) |
| Feature usage: WhisperKit | 70% | Telemetry (P2) |
| **Feature usage: AI Post-Processing** | **40%** | **Telemetry (P2)** **NEW v1.0** |
| **Feature usage: History View** | **30%** | **Telemetry (P2)** **NEW v1.0** |

### Quality Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| User satisfaction | >90% | Survey (P2) |
| Transcription accuracy (WER) | <10% | Manual evaluation |
| App crash rate | <0.1% | Crash reports (P2) |
| Average response time | <2s | Telemetry (P2) |

### Performance Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Hotkey response time | <100ms | Instruments |
| Recording start latency | <200ms | Instruments |
| Memory usage (idle) | <50 MB | Activity Monitor |
| Memory usage (recording) | <100 MB | Activity Monitor |
| Binary size | <20 MB | Build artifacts |

---

## Future Enhancements

### Phase 1: Core Improvements (v1.1 - v1.3)

**P1.1: Customizable Hotkey**
- Allow users to set custom hotkey combinations
- Avoid system shortcut conflicts
- Save preference to UserDefaults

**P1.2: Audio Level Meter**
- Real-time waveform during recording
- Visual feedback for audio quality
- Warning if too quiet/loud

**P1.3: Recording Duration Limit**
- Set maximum recording time (default: 10 min)
- Warning at 9 minutes
- Auto-stop at limit

**P1.4: Export History**
- Export to CSV, JSON, or plain text
- Filter by date range or service
- Include metadata (date, duration, service)

**P1.5: Playback**
- Replay recorded audio
- Useful for verifying transcription
- Delete audio after 24 hours (privacy)

---

### Phase 2: Enhanced Features (v2.0)

**P2.1: Language Selection**
- Support 90+ languages (WhisperKit capability)
- Auto-detect language (P2.2)
- Per-transcription language override

**P2.2: Edit Before Paste**
- Optional edit mode after transcription
- Quick corrections
- Then paste or save

**P2.3: Real-Time Transcription**
- Stream transcription as user speaks
- Useful for long recordings
- Requires streaming-capable model

**P2.4: Word Timestamps**
- Display timestamps for each word
- Navigate to specific timestamp
- Useful for editing

**P2.5: Text Formatting** ✅ **IMPLEMENTED in v1.0 via AI Post-Processing (F13)**
- Auto-capitalize sentences ✅
- Smart punctuation ✅
- Remove filler words ("um", "uh") - Partial (models can do this, but not explicitly prompted)

**P2.6: Snippets & Templates**
- Save common phrases as snippets
- Voice command to insert snippet
- Useful for emails, code comments

**P2.7: Multi-Device Sync**
- iCloud sync for history
- Sync settings across Macs
- Privacy considerations

---

### Phase 3: Advanced Features (v3.0)

**P3.1: Speaker Diarization**
- Identify and label different speakers
- Useful for meeting transcription
- Requires advanced ML model

**P3.2: Custom Vocabulary**
- Add technical terms, names, acronyms
- Improves accuracy for specialized content
- User-managed dictionary

**P3.3: Integration API**
- URL scheme for other apps to trigger recording
- Scriptable via AppleScript/Shortcuts
- Webhook for transcription complete

**P3.4: Team Features**
- Shared transcription history (optional)
- Team vocabulary
- Usage analytics for admins

**P3.5: iOS Companion App**
- Record on iPhone/iPad
- Sync to Mac for paste
- Uses Watch for quick capture

**P3.6: Meeting Mode**
- Longer recording limit (2+ hours)
- Summary generation (GPT-4)
- Action item extraction

---

## Risks & Mitigations

### Risk Matrix

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| WhisperKit Intel incompatibility confuses users | High | High | Clear error message, suggest OpenAI |
| OpenAI API costs deter users | Medium | Medium | Default to WhisperKit, explain costs |
| Transcription accuracy too low | High | Low | Offer both services, let user choose |
| Accessibility permission scares users | Medium | Medium | Clear explanation, optional feature |
| App crashes during recording | High | Low | Extensive testing, auto-save audio |
| Hotkey conflicts with other apps | Medium | Medium | Allow customization, detect conflicts |
| Privacy concerns with cloud service | Medium | High | Default to WhisperKit, transparent docs |
| Large model downloads on cellular | Low | Medium | Warn before download, allow cancel |

### Technical Risks

**Risk: WhisperKit API Changes**
- **Impact**: High (core feature breaks)
- **Likelihood**: Low (stable API)
- **Mitigation**: Pin to specific version, monitor releases, test updates

**Risk: OpenAI API Deprecation**
- **Impact**: High (cloud service breaks)
- **Likelihood**: Low (widely used API)
- **Mitigation**: Monitor OpenAI announcements, have fallback provider ready

**Risk: macOS API Changes**
- **Impact**: Medium (features break on new macOS)
- **Likelihood**: Medium (yearly macOS releases)
- **Mitigation**: Test on beta versions, follow deprecation notices

**Risk: KeyboardShortcuts Library Abandonment**
- **Impact**: Low (feature works, but no updates)
- **Likelihood**: Medium (single maintainer)
- **Mitigation**: Fork if needed, consider native implementation

---

## Open Questions

1. **Telemetry**: Should we add opt-in usage analytics?
   - **Pro**: Better understanding of usage patterns, identify bugs
   - **Con**: Privacy concerns, development overhead
   - **Decision**: Defer to v1.1, make strictly opt-in

2. **Monetization**: Should this be free forever or add paid features?
   - **Options**:
     - Free forever (rely on donations)
     - Freemium (basic free, advanced paid)
     - Paid app ($5-15)
   - **Decision**: Free v1.0, evaluate after 6 months

3. **Notarization**: Should we notarize for easier distribution?
   - **Pro**: Users don't need to right-click → Open workaround
   - **Con**: Requires Apple Developer account ($99/year)
   - **Decision**: Yes for v1.0 if budget allows

4. **App Store**: Should we distribute via Mac App Store?
   - **Pro**: Easier discovery, trusted distribution
   - **Con**: 30% revenue share, app review delays, sandbox restrictions
   - **Decision**: No for v1.0, consider for v2.0

5. **Localization**: Should we translate UI to other languages?
   - **Pro**: Broader audience
   - **Con**: Maintenance overhead, translation costs
   - **Decision**: English-only for v1.0, add top 5 languages in v1.2

---

## Success Criteria

**VoiceScribe v1.0 is successful if**:

1. ✅ 1,000+ users within 3 months
2. ✅ <1% crash rate
3. ✅ Average 4+ stars in user reviews
4. ✅ 100+ GitHub stars
5. ✅ Featured in at least 2 Mac productivity blogs/newsletters
6. ✅ Active community contributions (issues, PRs)
7. ✅ Users report using it daily (testimonials)

**Long-term success indicators**:

1. ✅ Becomes recommended tool in "best Mac productivity apps" lists
2. ✅ Sustained growth in active users (not just downloads)
3. ✅ Community builds plugins/extensions
4. ✅ Inspires similar projects (validation of concept)
5. ✅ Users choose VoiceScribe over built-in macOS Dictation

---

## Appendix

### Competitive Analysis

| Feature | VoiceScribe | macOS Dictation | Whisper Desktop | Talon Voice |
|---------|-------------|-----------------|-----------------|-------------|
| Local processing | ✅ | ✅ | ✅ | ✅ |
| Cloud option | ✅ | ✅ | ❌ | ❌ |
| Global hotkey | ✅ | ✅ | ❌ | ✅ |
| Auto-paste | ✅ | ✅ | ❌ | ✅ |
| History | ✅ | ❌ | ✅ | ❌ |
| **History UI with search** | ✅ **NEW** | ❌ | ⚠️ (basic) | ❌ |
| **AI Post-Processing** | ✅ **NEW** | ❌ | ❌ | ❌ |
| **Dual-mode enhancement** | ✅ **NEW** | ❌ | ❌ | ❌ |
| **Multiple transcription models** | ✅ **NEW** | ❌ | ⚠️ (Whisper only) | ❌ |
| Open source | ✅ | ❌ | ✅ | ❌ |
| Free | ✅ | ✅ | ✅ | $$ |
| Intel Mac | ⚠️ (cloud only) | ✅ | ✅ | ✅ |

**Key Differentiators**:
1. **Only tool with both local and cloud transcription**
2. **Unique dual-mode AI post-processing** (cloud or local) **NEW in v1.0**
3. **Full history UI with configurable limits and search** **NEW in v1.0**
4. **Multiple model options per service** (Whisper, GPT-4o, MLX) **NEW in v1.0**
5. **Open source and free**
6. **Modern Swift 6 / SwiftUI architecture**

---

## Version History

- **v1.0** (2025-01): Initial release
  - Global hotkey recording
  - WhisperKit and OpenAI support (3 models each)
  - Auto-paste functionality
  - **AI Post-Processing** with dual modes (OpenAI cloud / MLX local)
  - **Full History UI** with configurable limits (10/25/50/100)
  - **Click-to-copy** from history
  - **Service badges** and relative timestamps
  - Model management (WhisperKit: Base/Small/Medium, MLX: Qwen/Llama/Phi)
  - Settings panel with enhanced UI
  - Menu bar integration

---

## Conclusion

VoiceScribe addresses a clear need: fast, private, accurate voice-to-text transcription on macOS. By offering both local and cloud processing, it serves users across the privacy-convenience spectrum. The clean architecture and comprehensive documentation position it for long-term success as an open-source project.

**Next Steps**:
1. Complete v1.0 development
2. Beta testing with 10-20 users
3. Polish UI/UX based on feedback
4. Public launch on GitHub
5. Submit to product discovery sites (Product Hunt, Hacker News)
6. Monitor metrics and iterate

---

**Document maintained by**: Edd Mann
**Last updated**: 2025-01-20
**Status**: Living document (update as product evolves)
