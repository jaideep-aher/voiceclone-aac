import Foundation
import SwiftUI

enum Constants {
    /// Replace with your Railway URL (no trailing slash), e.g. `https://voiceclone-api.up.railway.app`
    static let apiBaseURLString = "https://YOUR_RAILWAY_URL"

    static var apiBaseURL: URL {
        guard let url = URL(string: apiBaseURLString) else {
            fatalError("Invalid Constants.apiBaseURLString — set your Railway URL in Constants.swift")
        }
        return url
    }

    static let keychainService = "com.voiceclone.aac.auth"
    static let keychainTokenAccount = "access_token"

    static let samplePhraseForRecording = """
    The quick brown fox jumps over the lazy dog. I love spending time with my family on sunny afternoons.
    """

    static let postClonePreviewText = "Hello, this is your voice clone."

    static let maxRecordingSeconds: TimeInterval = 15

    static let defaultQuickPhrases: [String] = [
        "Yes", "No", "Thank you", "Help", "Water", "Pain", "I love you", "Bathroom",
    ]

    /// Normalized quick-phrase texts for LRU / clear-cache protection.
    static var quickPhraseNormalizedSet: Set<String> {
        Set(defaultQuickPhrases.map { TextHashing.normalize($0) })
    }

    /// Max on-disk cache for synthesized audio before LRU eviction (500MB).
    /// In DEBUG, set env `VC_CACHE_LIMIT_1MB=1` on the scheme to test LRU quickly.
    static var audioCacheMaxBytes: Int64 {
        #if DEBUG
        if ProcessInfo.processInfo.environment["VC_CACHE_LIMIT_1MB"] == "1" {
            return 1 * 1024 * 1024
        }
        #endif
        return 500 * 1024 * 1024
    }

    static let phraseCategories: [String] = [
        "Medical", "Family", "Daily", "Emergency", "Custom",
    ]

    /// Maps display category to API value (lowercase)
    static func apiCategory(_ display: String) -> String {
        display.lowercased()
    }
}

extension Color {
    static let vcPrimary = Color(red: 43 / 255, green: 108 / 255, blue: 176 / 255)
    static let vcBackground = Color(red: 247 / 255, green: 250 / 255, blue: 252 / 255)
    static let vcAccentTeal = Color(red: 56 / 255, green: 178 / 255, blue: 172 / 255)
    static let vcCardShadow = Color.black.opacity(0.06)
}

extension Notification.Name {
    static let apiUnauthorized = Notification.Name("VoiceCloneAAC.apiUnauthorized")
}
