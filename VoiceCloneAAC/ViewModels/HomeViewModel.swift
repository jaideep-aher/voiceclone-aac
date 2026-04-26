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
            // Fetch all phrases; category filtering is done client-side
            phrases = try await api.fetchPhrases(category: nil)
        } catch {
            if case APIError.unauthorized = error {
                NotificationCenter.default.post(name: .apiUnauthorized, object: nil)
            }
            lastError = error.localizedDescription
        }
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
            isPlayingAudio = true
            try audio.play(data: data)
            // Optimistic local update — increment use_count & last_used_at without a network round-trip
            let now = Date()
            let matchIndex: Int?
            if let phraseId {
                matchIndex = phrases.firstIndex(where: { $0.id == phraseId })
            } else {
                matchIndex = phrases.firstIndex(where: { TextHashing.normalize($0.text) == TextHashing.normalize(trimmed) })
            }
            if let idx = matchIndex {
                let p = phrases[idx]
                phrases[idx] = Phrase(
                    id: p.id, userId: p.userId, text: p.text, category: p.category,
                    isQuickPhrase: p.isQuickPhrase, audioUrl: p.audioUrl,
                    useCount: p.useCount + 1, lastUsedAt: now, createdAt: p.createdAt
                )
            }
        } catch {
            if case APIError.unauthorized = error {
                onUnauthorized()
            }
            lastError = error.localizedDescription
        }
        isPlayingAudio = false
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

    // MARK: - Filtered / derived lists

    var filteredPhrases: [Phrase] {
        guard let cat = selectedCategory else { return phrases }
        let apiCat = Constants.apiCategory(cat)
        return phrases.filter { $0.category == apiCat }
    }

    var recentPhrases: [Phrase] {
        filteredPhrases
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(12)
            .map { $0 }
    }

    var searchResults: [Phrase] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return filteredPhrases }
        return filteredPhrases.filter { $0.text.lowercased().contains(q) }
    }

    @Published var searchQuery: String = ""
    @Published var isPlayingAudio = false

    func stopSpeaking() {
        audio.stopPlayback()
        isSpeaking = false
        isPlayingAudio = false
    }

    func setCategory(_ name: String?) {
        selectedCategory = name
        // client-side filter — no network call needed
    }

    func deletePhrase(_ phrase: Phrase) async {
        do {
            try await api.deletePhrase(id: phrase.id)
            phrases.removeAll { $0.id == phrase.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updatePhrase(_ phrase: Phrase, newText: String, newCategory: String) async {
        do {
            let updated = try await api.updatePhrase(id: phrase.id, text: newText, category: Constants.apiCategory(newCategory))
            if let idx = phrases.firstIndex(where: { $0.id == phrase.id }) {
                phrases[idx] = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
