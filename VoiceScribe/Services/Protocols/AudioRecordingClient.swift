import Foundation

@MainActor
protocol AudioRecordingClient: Sendable {
    var hasPermission: Bool { get }
    func requestPermission() async -> Bool
    func startRecording() async throws -> URL
    func stopRecording() async throws -> URL
    func cancelRecording() async
    func getAudioLevel() -> Float
}
