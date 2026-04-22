import CryptoKit
import Foundation

enum TextHashing {
    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Full 64-char hex SHA256 of normalized UTF-8 text (used for `{phrase_hash}.mp3`).
    static func phraseHash(_ text: String) -> String {
        let normalized = normalize(text)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
