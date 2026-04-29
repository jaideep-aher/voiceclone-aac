import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    enum Route: Equatable {
        case launching
        case welcome
        case auth(isSignUp: Bool)
        case voiceSetup
        case home
    }

    @Published var route: Route = .launching
    @Published var profile: UserProfile?
    @Published var lastError: String?

    private let api = APIService.shared

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        guard KeychainHelper.readToken() != nil else {
            route = .welcome
            return
        }
        do {
            let p = try await api.fetchProfile()
            profile = p
            syncCacheWithProfileVoice(p)
            route = p.voiceCloneStatus == .active ? .home : .voiceSetup
        } catch {
            if case APIError.unauthorized = error {
                signOut(clearTokenOnly: true)
                route = .welcome
            } else {
                lastError = error.localizedDescription
                route = .welcome
            }
        }
    }

    func beginSignUp() {
        route = .auth(isSignUp: true)
    }

    func beginSignIn() {
        route = .auth(isSignUp: false)
    }

    func backToWelcome() {
        route = .welcome
    }

    func handleSession(_ session: AuthSession) async throws {
        try KeychainHelper.save(token: session.accessToken)
        let p = try await api.fetchProfile()
        profile = p
        syncCacheWithProfileVoice(p)
        route = p.voiceCloneStatus == .active ? .home : .voiceSetup
    }

    func refreshProfile() async {
        do {
            let p = try await api.fetchProfile()
            profile = p
            syncCacheWithProfileVoice(p)
        } catch {
            if case APIError.unauthorized = error {
                signOut()
            }
        }
    }

    private func syncCacheWithProfileVoice(_ p: UserProfile) {
        guard let vid = p.voiceCloneId else { return }
        try? AudioCacheStore.shared.purgeStaleVoiceCaches(retainVoiceId: vid)
    }

    func voiceSetupCompleted() {
        route = .home
        Task { await refreshProfile() }
    }

    func goToVoiceSetup() {
        route = .voiceSetup
    }

    func signOut(clearTokenOnly: Bool = false) {
        KeychainHelper.deleteToken()
        profile = nil
        if !clearTokenOnly {
            route = .welcome
        }
    }

    func handleUnauthorized() {
        signOut()
    }

    /// Skip login — go straight to home as a guest (system TTS, no sync).
    func skipAuth() {
        route = .home
    }
}
