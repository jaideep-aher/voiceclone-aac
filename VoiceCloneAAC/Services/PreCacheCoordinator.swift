import Foundation
import SwiftUI

@MainActor
final class PreCacheCoordinator: ObservableObject {
    static let shared = PreCacheCoordinator()

    @Published var progress: (done: Int, total: Int)?
    @Published private(set) var isRunning = false

    func startQuickPhrasesPrecache(voiceId: String, phrases: [String] = Constants.defaultQuickPhrases) {
        guard !isRunning else { return }
        isRunning = true
        progress = (0, phrases.count)

        Task { @MainActor in
            let store = AudioCacheStore.shared
            var done = 0
            let total = phrases.count

            for phrase in phrases {
                if Task.isCancelled { break }
                if store.hasCached(text: phrase, voiceId: voiceId) {
                    done += 1
                    progress = (done, total)
                    continue
                }
                do {
                    let data = try await APIService.shared.synthesizeSpeech(
                        text: phrase,
                        voiceId: nil,
                        phraseId: nil
                    )
                    try store.saveAudio(data: data, text: phrase, voiceId: voiceId)
                } catch {
                    // Continue batch; individual failures are non-fatal.
                }
                done += 1
                progress = (done, total)
            }

            isRunning = false
            progress = nil
        }
    }
}
