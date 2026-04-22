import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var phrases: [Phrase] = []
    @Published var selectedCategory: String?
    @Published var isLoadingPhrases = false
    @Published var isSpeaking = false
    @Published var lastError: String?
    @Published var draftText: String = ""
    @Published var offlineInfoMessage: String?

    private let api = APIService.shared
    private let cache = AudioCacheStore.shared
    private let audio = AudioService()

    var audioService: AudioService { audio }

    func bindPlaybackRate(_ rate: Float) {
        audio.playbackRate = rate
    }

    func isTextCached(_ text: String, voiceId: String?) -> Bool {
        guard let vid = voiceId else { return false }
        return cache.hasCached(text: text, voiceId: vid)
    }

    func cacheStatusLabel(for text: String, voiceId: String?) -> String {
        guard voiceId != nil else { return "Needs internet" }
        return isTextCached(text, voiceId: voiceId) ? "Cached ✓" : "Needs internet"
    }

    func loadPhrases() async {
        guard NetworkMonitor.shared.isConnected else { return }
        isLoadingPhrases = true
        defer { isLoadingPhrases = false }
        do {
            let cat = selectedCategory.map { Constants.apiCategory($0) }
            phrases = try await api.fetchPhrases(category: cat)
        } catch {
            if case APIError.unauthorized = error {
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            }
            lastError = error.localizedDescription
        }
    }

    func setCategory(_ name: String?) {
        selectedCategory = name
        Task { await loadPhrases() }
    }

    func speak(
        _ text: String,
        phraseId: UUID?,
        voiceId: String?,
        categoryForQueue: String,
        onUnauthorized: @escaping () -> Void
    ) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let vid = voiceId else {
            lastError = "Voice clone not ready yet."
            return
        }

        offlineInfoMessage = nil
        isSpeaking = true
        defer { isSpeaking = false }

        if let data = cache.loadAudioData(text: trimmed, voiceId: vid) {
            do {
                try audio.play(data: data)
            } catch {
                lastError = error.localizedDescription
            }
            return
        }

        guard NetworkMonitor.shared.isConnected else {
            cache.enqueuePending(text: trimmed, category: categoryForQueue)
            offlineInfoMessage = "Will synthesize when back online."
            return
        }

        do {
            let data = try await api.synthesizeSpeech(
                text: trimmed,
                voiceId: nil,
                phraseId: phraseId
            )
            try cache.saveAudio(data: data, text: trimmed, voiceId: vid)
            try audio.play(data: data)
            await loadPhrases()
        } catch {
            if case APIError.unauthorized = error {
                onUnauthorized()
            }
            lastError = error.localizedDescription
        }
    }

    func processPendingQueue(voiceId: String?) async {
        guard NetworkMonitor.shared.isConnected, let vid = voiceId else { return }
        let pending = cache.fetchPending()
        guard !pending.isEmpty else { return }
        for p in pending {
            do {
                let data = try await api.synthesizeSpeech(
                    text: p.text,
                    voiceId: nil,
                    phraseId: nil
                )
                try cache.saveAudio(data: data, text: p.text, voiceId: vid)
                cache.deletePending(p)
            } catch {
                cache.markPendingFailed(p)
            }
        }
        await loadPhrases()
    }

    func addPhrase(text: String, category: String) async throws {
        guard NetworkMonitor.shared.isConnected else {
            throw HomeError.needsInternet
        }
        let cat = Constants.apiCategory(category)
        _ = try await api.createPhrase(text: text, category: cat, isQuickPhrase: false)
        await loadPhrases()
    }

    enum HomeError: LocalizedError {
        case needsInternet
        var errorDescription: String? {
            "Connect to the internet to add phrases."
        }
    }

    var recentPhrases: [Phrase] {
        phrases
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(12)
            .map { $0 }
    }
}
