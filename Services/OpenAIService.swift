import Foundation
import os.log

private let logger = Logger(subsystem: "com.eddmann.VoiceScribe", category: "OpenAIService")

/// OpenAI Whisper API service implementation
@MainActor
final class OpenAIService: TranscriptionService {
    let name = "OpenAI Whisper"
    let identifier = "openai"
    let requiresAPIKey = true

    private let apiEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let model = "whisper-1"

    var isAvailable: Bool {
        get async {
            do {
                try await validateConfiguration()
                return true
            } catch {
                return false
            }
        }
    }

    func validateConfiguration() async throws {
        guard let apiKey = await KeychainManager.shared.retrieve(for: identifier),
              !apiKey.isEmpty else {
            throw VoiceScribeError.noAPIKey(service: name)
        }

        // Validate API key format (OpenAI keys start with "sk-")
        guard apiKey.hasPrefix("sk-") else {
            throw VoiceScribeError.invalidAPIKey(service: name)
        }
    }

    func transcribe(audioURL: URL) async throws -> String {
        // Validate configuration first
        try await validateConfiguration()

        guard let apiKey = await KeychainManager.shared.retrieve(for: identifier) else {
            throw VoiceScribeError.noAPIKey(service: name)
        }

        // Create multipart/form-data request
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type")

        // Build multipart body
        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")

        // Add audio file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; ")
        body.append("filename=\"\(audioURL.lastPathComponent)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")

        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append(audioData)
            body.append("\r\n")
        } catch {
            throw VoiceScribeError.recordingFailed(
                underlying: "Could not read audio file: \(error.localizedDescription)"
            )
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        logger.info("Sending transcription request to OpenAI (file size: \(body.count) bytes)")

        // Perform request with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoiceScribeError.networkError(underlying: "Invalid response type")
            }

            logger.info("OpenAI response: \(httpResponse.statusCode)")

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                // Success
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                logger.info("Transcription successful: \(result.text.count) chars")
                return result.text.trimmingCharacters(in: .whitespacesAndNewlines)

            case 401:
                throw VoiceScribeError.invalidAPIKey(service: name)

            case 429:
                throw VoiceScribeError.transcriptionFailed(
                    service: name,
                    reason: "Rate limit exceeded. Please try again later."
                )

            default:
                // Try to parse error message
                if let errorResponse = try? JSONDecoder().decode(
                    OpenAIErrorResponse.self,
                    from: data
                ) {
                    throw VoiceScribeError.transcriptionFailed(
                        service: name,
                        reason: errorResponse.error.message
                    )
                } else {
                    throw VoiceScribeError.transcriptionFailed(
                        service: name,
                        reason: "HTTP \(httpResponse.statusCode)"
                    )
                }
            }
        } catch let error as VoiceScribeError {
            throw error
        } catch {
            logger.error("Network error: \(error.localizedDescription)")
            throw VoiceScribeError.networkError(underlying: error.localizedDescription)
        }
    }
}

// MARK: - Response Models
private struct OpenAIResponse: Decodable {
    let text: String
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIError

    struct OpenAIError: Decodable {
        let message: String
        let type: String?
        let code: String?
    }
}

// MARK: - Data Extension
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
