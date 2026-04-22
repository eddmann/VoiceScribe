import Foundation

/// Comprehensive error handling for VoiceScribe with user-friendly messages
enum VoiceScribeError: LocalizedError, Sendable {
    // Permission errors
    case microphonePermissionDenied
    case microphonePermissionRestricted

    // Recording errors
    case recordingInitializationFailed
    case recordingFailed(underlying: String)
    case noAudioRecorded
    case noSpeechDetected

    // Transcription errors
    case transcriptionFailed(engine: String, reason: String)
    case engineNotAvailable(engine: String)

    // Configuration errors
    case invalidConfiguration(reason: String)
    case modelNotFound(modelName: String)
    case modelDownloadFailed(modelName: String, reason: String)

    // Post-processing errors
    case cleanupFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone Access Required"
        case .microphonePermissionRestricted:
            return "Microphone Access Restricted"
        case .recordingInitializationFailed:
            return "Could Not Initialize Recording"
        case .recordingFailed(let underlying):
            return "Recording Failed: \(underlying)"
        case .noAudioRecorded:
            return "No Audio Recorded"
        case .noSpeechDetected:
            return "No Speech Detected"
        case .transcriptionFailed(let engine, let reason):
            return "\(engine) Transcription Failed: \(reason)"
        case .engineNotAvailable(let engine):
            return "\(engine) Not Available"
        case .invalidConfiguration(let reason):
            return "Invalid Configuration: \(reason)"
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' Not Downloaded"
        case .modelDownloadFailed(let modelName, let reason):
            return "Failed to Download '\(modelName)': \(reason)"
        case .cleanupFailed(let reason):
            return "Cleanup Failed: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Go to System Settings → Privacy & Security → Microphone and enable access for VoiceScribe."
        case .microphonePermissionRestricted:
            return "Microphone access is restricted by your system administrator. Contact your IT department."
        case .recordingInitializationFailed:
            return "Try restarting VoiceScribe. If the problem persists, check your microphone settings."
        case .noAudioRecorded:
            return "Make sure your microphone is working and try recording again."
        case .noSpeechDetected:
            return "Try speaking a little closer to the microphone and record again."
        case .engineNotAvailable(let engine):
            return "\(engine) is currently unavailable. Check your model setup in Settings."
        case .modelNotFound:
            return "Download the model from Settings → Local Models to use offline transcription."
        case .modelDownloadFailed:
            return "Check your internet connection and try downloading the model again."
        case .cleanupFailed:
            return "The original transcript is still available even though cleanup failed."
        default:
            return nil
        }
    }

    var failureReason: String? {
        switch self {
        case .microphonePermissionDenied:
            return "VoiceScribe needs microphone access to record audio for transcription."
        case .transcriptionFailed(_, let reason):
            return reason
        case .recordingFailed(let underlying):
            return underlying
        default:
            return nil
        }
    }
}
