import SwiftUI

@main
struct VoiceCloneAACApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        _ = PersistenceController.shared
        _ = NetworkMonitor.shared
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(authViewModel)
                .preferredColorScheme(.light)
        }
    }
}
