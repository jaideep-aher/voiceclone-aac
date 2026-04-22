import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case rateLimited(retryAfter: String?)
    case server(status: Int, message: String?)
    case decoding(Error)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired. Please sign in again."
        case .rateLimited(let s): return s.map { "Rate limited. Retry after \($0)." } ?? "Rate limited. Try again later."
        case .server(_, let m): return m ?? "Server error"
        case .decoding: return "Could not read server response."
        case .transport(let e): return e.localizedDescription
        case .invalidURL: return "Invalid API URL."
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let session: URLSession
    private let baseURL: URL
    private var tokenProvider: () -> String?

    init(
        baseURL: URL = Constants.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping () -> String? = { KeychainHelper.readToken() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    func setTokenProvider(_ provider: @escaping () -> String?) {
        tokenProvider = provider
    }

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        d.dateDecodingStrategy = .custom { dec in
            let c = try dec.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = fmt.date(from: s) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(in: c, debugDescription: s)
        }
        return d
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private func authorizedRequest(path: String, method: String, body: Data? = nil, contentType: String? = "application/json") throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpBody = body
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.server(status: -1, message: "Not HTTP")
            }
            if http.statusCode == 401 { throw APIError.unauthorized }
            if http.statusCode == 503 {
                let ra = http.value(forHTTPHeaderField: "Retry-After")
                throw APIError.rateLimited(retryAfter: ra)
            }
            return (data, http)
        } catch let e as APIError {
            throw e
        } catch {
            throw APIError.transport(error)
        }
    }

    // MARK: - Auth

    func signUp(email: String, password: String, displayName: String) async throws -> AuthSession {
        let body = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "display_name": displayName,
        ])
        let req = try authorizedRequest(path: "/api/auth/signup", method: "POST", body: body)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(AuthSession.self, from: data)
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let body = try JSONSerialization.data(withJSONObject: ["email": email, "password": password])
        let req = try authorizedRequest(path: "/api/auth/login", method: "POST", body: body)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(AuthSession.self, from: data)
    }

    func signInWithApple(idToken: String, nonce: String?) async throws -> AuthSession {
        var dict: [String: Any] = ["id_token": idToken]
        if let nonce { dict["nonce"] = nonce }
        let body = try JSONSerialization.data(withJSONObject: dict)
        let req = try authorizedRequest(path: "/api/auth/apple", method: "POST", body: body)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(AuthSession.self, from: data)
    }

    // MARK: - Profile

    func fetchProfile() async throws -> UserProfile {
        let req = try authorizedRequest(path: "/api/profile", method: "GET", body: nil, contentType: nil)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(UserProfile.self, from: data)
    }

    // MARK: - Phrases

    func fetchPhrases(category: String?) async throws -> [Phrase] {
        var path = "/api/phrases"
        if let category {
            let q = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category
            path += "?category=\(q)"
        }
        let req = try authorizedRequest(path: path, method: "GET", body: nil, contentType: nil)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode([Phrase].self, from: data)
    }

    func createPhrase(text: String, category: String, isQuickPhrase: Bool) async throws -> Phrase {
        let enc = try encoder().encode(CreatePhraseRequest(text: text, category: category, isQuickPhrase: isQuickPhrase))
        let req = try authorizedRequest(path: "/api/phrases", method: "POST", body: enc)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(Phrase.self, from: data)
    }

    // MARK: - Voice

    func fetchVoiceStatus() async throws -> VoiceStatusResponse {
        let req = try authorizedRequest(path: "/api/voice/status", method: "GET", body: nil, contentType: nil)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(VoiceStatusResponse.self, from: data)
    }

    func cloneVoice(fileURL: URL, mimeType: String) async throws -> VoiceCloneResult {
        guard let url = URL(string: "/api/voice/clone", relativeTo: baseURL) else { throw APIError.invalidURL }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return try decoder().decode(VoiceCloneResult.self, from: data)
    }

    func synthesizeSpeech(text: String, voiceId: String?, phraseId: UUID?) async throws -> Data {
        var payload: [String: Any] = ["text": text]
        if let voiceId { payload["voice_id"] = voiceId }
        if let phraseId { payload["phrase_id"] = phraseId.uuidString }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let req = try authorizedRequest(path: "/api/voice/synthesize", method: "POST", body: body)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
        return data
    }

    func deleteVoiceClone() async throws {
        let req = try authorizedRequest(path: "/api/voice/clone", method: "DELETE", body: nil, contentType: nil)
        let (data, http) = try await perform(req)
        guard (200 ..< 300).contains(http.statusCode) else {
            throw Self.apiError(data: data, status: http.statusCode)
        }
    }

    private static func apiError(data: Data, status: Int) -> APIError {
        struct ErrBody: Decodable { let error: String? }
        let msg = (try? JSONDecoder().decode(ErrBody.self, from: data))?.error
        if status == 401 { return .unauthorized }
        return .server(status: status, message: msg)
    }
}
