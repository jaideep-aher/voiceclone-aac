import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    enum Route: Equatable {
        case launching
        case voiceSetup
        case home
    }

    @Published var route: Route = .launching
    @Published var profile: UserProfile?

    init() {
        Task { await bootstrap() }
    }

    func bootstrap() async {
        // No account required — go straight to the app.
        route = .home
    }

    func goToVoiceSetup() {
        route = .voiceSetup
    }

    func voiceSetupCompleted() {
        route = .home
    }

    private func syncCacheWithProfileVoice(_ p: UserProfile) {
        guard let vid = p.voiceCloneId else { return }
        try? AudioCacheStore.shared.purgeStaleVoiceCaches(retainVoiceId: vid)
    }
}
