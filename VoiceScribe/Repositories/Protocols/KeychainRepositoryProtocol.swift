import Foundation

protocol KeychainRepositoryProtocol: Sendable {
    func save(key: String, for account: String) async throws
    func retrieve(for account: String) async -> String?
    func delete(for account: String) async throws
    func hasKey(for account: String) async -> Bool
}
