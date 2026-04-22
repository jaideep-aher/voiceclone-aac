import Foundation

enum VoiceCloneStatus: String, Codable {
    case none
    case processing
    case active
    case failed
}

struct VoiceStatusResponse: Codable {
    let voiceId: String?
    let status: VoiceCloneStatus

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case status
    }
}

struct VoiceCloneResult: Codable {
    let voiceId: String
    let status: VoiceCloneStatus

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case status
    }
}
