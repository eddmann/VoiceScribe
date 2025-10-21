import Foundation
import Security

/// Thread-safe keychain manager for secure API key storage
actor KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.eddmann.VoiceScribe"

    private init() {}

    /// Save an API key to the keychain
    /// - Parameters:
    ///   - key: The API key to save
    ///   - account: The account identifier (e.g., "openai", "whisperkit")
    /// - Throws: VoiceScribeError if save fails
    func save(key: String, for account: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw VoiceScribeError.invalidConfiguration(reason: "Invalid API key format")
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw VoiceScribeError.invalidConfiguration(
                reason: "Failed to save API key: \(status)"
            )
        }
    }

    /// Retrieve an API key from the keychain
    /// - Parameter account: The account identifier
    /// - Returns: The API key, or nil if not found
    func retrieve(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    /// Delete an API key from the keychain
    /// - Parameter account: The account identifier
    func delete(for account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw VoiceScribeError.invalidConfiguration(
                reason: "Failed to delete API key: \(status)"
            )
        }
    }

    /// Check if an API key exists for an account
    /// - Parameter account: The account identifier
    /// - Returns: true if key exists
    func hasKey(for account: String) -> Bool {
        return retrieve(for: account) != nil
    }
}
