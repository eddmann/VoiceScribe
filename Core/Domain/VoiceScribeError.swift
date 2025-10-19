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

    // Transcription errors
    case transcriptionFailed(service: String, reason: String)
    case serviceNotAvailable(service: String)
    case noAPIKey(service: String)
    case invalidAPIKey(service: String)
    case networkError(underlying: String)

    // Configuration errors
    case invalidConfiguration(reason: String)
    case modelNotFound(modelName: String)
    case modelDownloadFailed(modelName: String, reason: String)

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
        case .transcriptionFailed(let service, let reason):
            return "\(service) Transcription Failed: \(reason)"
        case .serviceNotAvailable(let service):
            return "\(service) Not Available"
        case .noAPIKey(let service):
            return "No API Key for \(service)"
        case .invalidAPIKey(let service):
            return "Invalid API Key for \(service)"
        case .networkError(let underlying):
            return "Network Error: \(underlying)"
        case .invalidConfiguration(let reason):
            return "Invalid Configuration: \(reason)"
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' Not Downloaded"
        case .modelDownloadFailed(let modelName, let reason):
            return "Failed to Download '\(modelName)': \(reason)"
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
        case .noAPIKey(let service):
            return "Open Settings and add your \(service) API key to enable transcription."
        case .invalidAPIKey:
            return "Check your API key in Settings. Make sure it's copied correctly from your provider."
        case .networkError:
            return "Check your internet connection and try again."
        case .serviceNotAvailable(let service):
            return "\(service) is currently not configured. Open Settings to set it up."
        case .modelNotFound:
            return "Download the model from Settings → Local Models to use offline transcription."
        case .modelDownloadFailed:
            return "Check your internet connection and try downloading the model again."
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
        case .networkError(let underlying):
            return underlying
        default:
            return nil
        }
    }
}
