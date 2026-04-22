import Foundation

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

struct UserProfile: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let voiceCloneId: String?
    let voiceCloneStatus: VoiceCloneStatus
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case voiceCloneId = "voice_clone_id"
        case voiceCloneStatus = "voice_clone_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
