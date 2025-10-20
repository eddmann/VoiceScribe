import Foundation
import AVFoundation
import os.log

/// Modern audio recorder using async/await and Swift Concurrency
@MainActor
final class AudioRecorder: NSObject, Sendable {
    nonisolated private static let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "AudioRecorder")

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private(set) var isRecording = false

    /// Check microphone permission status
    /// Note: On macOS, AVAudioRecorder will automatically prompt for permission
    /// when record() is first called. This property checks current status.
    var hasPermission: Bool {
        #if os(macOS)
        // For AVAudioRecorder on macOS, we can't reliably check permission ahead of time
        // The system will prompt automatically when record() is called
        return true
        #else
        AVAudioApplication.shared.recordPermission == .granted
        #endif
    }

    /// Request microphone permission
    /// Note: On macOS with AVAudioRecorder, the permission dialog appears automatically
    /// when you first call recorder.record()
    func requestPermission() async -> Bool {
        #if os(macOS)
        // On macOS, AVAudioRecorder triggers permission automatically
        // No need for explicit request
        return true
        #else
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #endif
    }

    /// Start recording audio
    /// - Returns: URL where audio is being recorded
    /// - Throws: VoiceScribeError if recording fails to start
    /// - Note: On macOS, the system will automatically prompt for microphone permission
    ///         when recorder.record() is first called
    func startRecording() async throws -> URL {
        // Create temporary file for recording
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "voicescribe-\(UUID().uuidString).m4a"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        // Recording settings: high-quality M4A
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create and start recorder
        do {
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true

            guard recorder.record() else {
                throw VoiceScribeError.recordingInitializationFailed
            }

            audioRecorder = recorder
            recordingURL = fileURL
            isRecording = true

            Self.logger.info("Recording started: \(fileURL.lastPathComponent)")
            return fileURL
        } catch {
            Self.logger.error("Failed to start recording: \(error.localizedDescription)")
            throw VoiceScribeError.recordingFailed(underlying: error.localizedDescription)
        }
    }

    /// Stop recording and return the audio file URL
    /// - Returns: URL of the recorded audio file
    /// - Throws: VoiceScribeError if no recording is in progress
    func stopRecording() async throws -> URL {
        guard let recorder = audioRecorder, let url = recordingURL else {
            throw VoiceScribeError.recordingFailed(underlying: "No active recording")
        }

        recorder.stop()
        isRecording = false

        // Verify file was created
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoiceScribeError.noAudioRecorded
        }

        Self.logger.info("Recording stopped: \(url.lastPathComponent)")
        return url
    }

    /// Get current audio level (0.0 to 1.0)
    /// Call this regularly while recording to show visual feedback
    func getAudioLevel() -> Float {
        guard let recorder = audioRecorder, isRecording else {
            return 0.0
        }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)

        // Convert dB to 0-1 range (dB range is typically -160 to 0)
        let minDb: Float = -60.0
        let maxDb: Float = 0.0

        let normalized = (power - minDb) / (maxDb - minDb)
        return max(0.0, min(1.0, normalized))
    }

    /// Cancel current recording and delete the file
    func cancelRecording() async {
        guard let recorder = audioRecorder else { return }

        recorder.stop()
        isRecording = false

        // Delete the recording file
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            Self.logger.info("Recording cancelled and deleted: \(url.lastPathComponent)")
        }

        audioRecorder = nil
        recordingURL = nil
    }

    /// Clean up old temporary recording files
    static func cleanupOldRecordings() {
        let tempDirectory = FileManager.default.temporaryDirectory

        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: tempDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            let oldRecordings = files.filter { url in
                url.lastPathComponent.hasPrefix("voicescribe-") &&
                url.pathExtension == "m4a"
            }

            for file in oldRecordings {
                try? FileManager.default.removeItem(at: file)
            }

            if !oldRecordings.isEmpty {
                Self.logger.info("Cleaned up \(oldRecordings.count) old recording(s)")
            }
        } catch {
            Self.logger.error("Failed to cleanup old recordings: \(error.localizedDescription)")
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(
        _ recorder: AVAudioRecorder,
        successfully flag: Bool
    ) {
        if !flag {
            Self.logger.error("Recording finished unsuccessfully")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(
        _ recorder: AVAudioRecorder,
        error: (any Error)?
    ) {
        if let error = error {
            Self.logger.error("Recording encode error: \(error.localizedDescription)")
        }
    }
}

