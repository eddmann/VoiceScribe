import Foundation
import os.log

/// OpenAI Transcription API service implementation
actor OpenAIService: TranscriptionService {
    nonisolated private static let logger = Logger(
        subsystem: "com.eddmann.VoiceScribe",
        category: "OpenAIService"
    )
    let name = "OpenAI Transcription"
    let identifier = "openai"
    let requiresAPIKey = true

    private let keychain: KeychainRepositoryProtocol
    private let apiEndpoint = "https://api.openai.com/v1/audio/transcriptions"
    private let chatEndpoint = "https://api.openai.com/v1/chat/completions"

    private var progressHandler: (@Sendable (String) -> Void)?

    /// Available OpenAI transcription models
    enum Model: String, CaseIterable, Codable {
        case whisper1 = "whisper-1"
        case gpt4oTranscribe = "gpt-4o-transcribe"
        case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"

        var displayName: String {
            switch self {
            case .whisper1:
                return "Whisper V2"
            case .gpt4oTranscribe:
                return "GPT-4o Transcribe"
            case .gpt4oMiniTranscribe:
                return "GPT-4o Mini Transcribe"
            }
        }

        var description: String {
            switch self {
            case .whisper1:
                return "Powered by open source Whisper V2 • Standard transcription model"
            case .gpt4oTranscribe:
                return "GPT-4o powered transcription • Higher accuracy than Whisper"
            case .gpt4oMiniTranscribe:
                return "Lighter GPT-4o variant • Faster and more cost-effective"
            }
        }
    }

    private struct OpenAIResponse: Decodable {
        let text: String
    }

    private struct ChatCompletionResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String
        }
    }

    private struct OpenAIErrorResponse: Decodable {
        let error: OpenAIError

        struct OpenAIError: Decodable {
            let message: String
            let type: String?
            let code: String?
        }
    }

    private var selectedModel: Model {
        if let savedModel = UserDefaults.standard.string(forKey: SettingsKeys.openAIModel),
           let model = Model(rawValue: savedModel) {
            return model
        }
        return .whisper1 // Default
    }

    init(keychain: KeychainRepositoryProtocol = KeychainRepository.shared) {
        self.keychain = keychain
    }

    private func append(_ string: String, to data: inout Data) {
        if let encoded = string.data(using: .utf8) {
            data.append(encoded)
        }
    }

    func setProgressHandler(_ handler: (@Sendable (String) -> Void)?) async {
        progressHandler = handler
    }

    /// Check if post-processing is enabled
    private var isPostProcessingEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKeys.openAIPostProcessEnabled)
    }

    /// Reload the model selection from UserDefaults
    func reloadModelFromPreferences() async {
        // Model is read from UserDefaults on each use via computed property
        Self.logger.info("Reloaded OpenAI model from preferences: \(self.selectedModel.rawValue)")
    }

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
        guard let apiKey = await keychain.retrieve(for: identifier),
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

        guard let apiKey = await keychain.retrieve(for: identifier) else {
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
        append("--\(boundary)\r\n", to: &body)
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n", to: &body)
        append("\(selectedModel.rawValue)\r\n", to: &body)

        // Add audio file
        append("--\(boundary)\r\n", to: &body)
        append("Content-Disposition: form-data; name=\"file\"; ", to: &body)
        append("filename=\"\(audioURL.lastPathComponent)\"\r\n", to: &body)
        append("Content-Type: audio/m4a\r\n\r\n", to: &body)

        do {
            let audioData = try Data(contentsOf: audioURL)
            body.append(audioData)
            append("\r\n", to: &body)
        } catch {
            throw VoiceScribeError.recordingFailed(
                underlying: "Could not read audio file: \(error.localizedDescription)"
            )
        }

        append("--\(boundary)--\r\n", to: &body)
        request.httpBody = body

        Self.logger.info("Sending transcription request to OpenAI (file size: \(body.count) bytes)")

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

            Self.logger.info("OpenAI response: \(httpResponse.statusCode)")

            // Handle different status codes
            switch httpResponse.statusCode {
            case 200:
                // Success
                let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
                Self.logger.info("Transcription successful: \(result.text.count) chars")
                var transcribedText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                // Apply post-processing if enabled
                if isPostProcessingEnabled {
                    Self.logger.info("Post-processing enabled, applying AI enhancement...")
                    progressHandler?("Enhancing with AI post-processing...")
                    do {
                        transcribedText = try await postProcess(text: transcribedText, apiKey: apiKey)
                        Self.logger.info("Post-processing successful")
                    } catch {
                        // Log error but don't fail the transcription
                        Self.logger.error("Post-processing failed: \(error.localizedDescription)")
                        // Continue with original transcription
                    }
                }

                return transcribedText

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
            Self.logger.error("Network error: \(error.localizedDescription)")
            throw VoiceScribeError.networkError(underlying: error.localizedDescription)
        }
    }

    // MARK: - Post-Processing

    /// Post-process transcribed text using GPT to improve formatting and clarity
    private func postProcess(text: String, apiKey: String) async throws -> String {
        Self.logger.info("Starting post-processing with GPT")

        // Create request
        var request = URLRequest(url: URL(string: chatEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build request body
        let systemPrompt = """
        You are a transcription post-processor. Your task is to improve the given transcription by:
        - Adding proper punctuation and capitalization
        - Fixing obvious transcription errors
        - Adding paragraph breaks where appropriate
        - Maintaining the original meaning and content

        Return ONLY the cleaned text without any explanations, comments, or additional content.
        """

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw VoiceScribeError.postProcessingFailed(reason: "Failed to encode request")
        }

        // Perform request
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoiceScribeError.postProcessingFailed(reason: "Invalid response type")
            }

            Self.logger.info("Post-processing response: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                guard let content = result.choices.first?.message.content else {
                    throw VoiceScribeError.postProcessingFailed(reason: "No content in response")
                }
                return content.trimmingCharacters(in: .whitespacesAndNewlines)

            case 401:
                throw VoiceScribeError.invalidAPIKey(service: name)

            default:
                if let errorResponse = try? JSONDecoder().decode(
                    OpenAIErrorResponse.self,
                    from: data
                ) {
                    throw VoiceScribeError.postProcessingFailed(reason: errorResponse.error.message)
                } else {
                    throw VoiceScribeError.postProcessingFailed(
                        reason: "HTTP \(httpResponse.statusCode)"
                    )
                }
            }
        } catch let error as VoiceScribeError {
            throw error
        } catch {
            Self.logger.error("Post-processing network error: \(error.localizedDescription)")
            throw VoiceScribeError.postProcessingFailed(reason: error.localizedDescription)
        }
    }
}
