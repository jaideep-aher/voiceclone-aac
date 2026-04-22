import Foundation

struct Phrase: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let text: String
    let category: String
    let isQuickPhrase: Bool
    let audioUrl: String?
    let useCount: Int
    let lastUsedAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case text
        case category
        case isQuickPhrase = "is_quick_phrase"
        case audioUrl = "audio_url"
        case useCount = "use_count"
        case lastUsedAt = "last_used_at"
        case createdAt = "created_at"
    }
}

struct CreatePhraseRequest: Encodable {
    let text: String
    let category: String
    let isQuickPhrase: Bool

    enum CodingKeys: String, CodingKey {
        case text
        case category
        case isQuickPhrase = "is_quick_phrase"
    }
}
