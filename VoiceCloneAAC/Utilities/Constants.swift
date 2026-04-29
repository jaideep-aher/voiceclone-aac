import Foundation
import SwiftUI

enum Constants {
    /// API base URL — resolved in priority order:
    ///   1. VC_API_URL environment variable on the scheme (useful for CI / switching staging vs prod)
    ///   2. VC_API_URL key in the app's Info.plist (set via a .xcconfig file for each build config)
    ///   3. Hardcoded fallback below — update this when you have your Railway URL
    static let apiBaseURLString: String = {
        // 1. Scheme env var (Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables)
        if let env = ProcessInfo.processInfo.environment["VC_API_URL"], !env.isEmpty {
            return env
        }
        // 2. Info.plist (add VC_API_URL key pointing to $(VC_API_URL) from .xcconfig)
        if let plist = Bundle.main.object(forInfoDictionaryKey: "VC_API_URL") as? String,
           !plist.isEmpty, !plist.hasPrefix("$(") {
            return plist
        }
        // 3. Hardcoded fallback
        return "https://voiceclone-aac-production.up.railway.app"
    }()

    /// Returns true when the backend URL is still a placeholder (not yet configured).
    static var apiURLIsPlaceholder: Bool {
        apiBaseURLString.contains("YOUR_RAILWAY_URL")
    }

    static var apiBaseURL: URL {
        // Fall back to a dummy URL instead of crashing — the app will show
        // a "Backend not configured" screen via AuthViewModel.bootstrap().
        URL(string: apiBaseURLString) ?? URL(string: "https://not-configured.invalid")!
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
