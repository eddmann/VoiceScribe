//
//  DemoMode.swift
//  VoiceScribe
//
//  Created by Edd on 2026-02-02.
//

#if DEBUG
import Foundation

/// Demo modes for App Store screenshots.
/// Launch with `--demo <mode>` to activate.
enum DemoMode: String, CaseIterable {
    /// Recording bar in idle state, ready to record
    case idle

    /// Active recording with animated waveform
    case recording

    /// Transcription in progress
    case processing

    /// Transcription completed, shows "Pasted!"
    case completed

    /// Error state display
    case error

    /// History view populated with sample records
    case historyPopulated

    /// History view empty state
    case historyEmpty

    /// Parses demo mode from command line arguments.
    /// Returns nil if no valid demo mode is specified.
    static func fromArguments() -> DemoMode? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--demo"),
              index + 1 < args.count else { return nil }
        return DemoMode(rawValue: args[index + 1])
    }

    /// Whether this mode shows the history window instead of recording bar
    var showsHistoryWindow: Bool {
        switch self {
        case .historyPopulated, .historyEmpty:
            return true
        default:
            return false
        }
    }
}
#endif
