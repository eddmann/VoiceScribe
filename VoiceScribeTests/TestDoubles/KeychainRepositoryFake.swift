import Foundation
@testable import VoiceScribe

actor KeychainRepositoryFake: KeychainRepositoryProtocol {
    private var store: [String: String] = [:]

    func save(key: String, for account: String) async throws {
        store[account] = key
    }

    func retrieve(for account: String) async -> String? {
        store[account]
    }

    func delete(for account: String) async throws {
        store.removeValue(forKey: account)
    }

    func hasKey(for account: String) async -> Bool {
        store[account] != nil
    }
}
