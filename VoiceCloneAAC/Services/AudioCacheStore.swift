import CoreData
import Foundation
import SwiftUI

@MainActor
final class AudioCacheStore: ObservableObject {
    static let shared = AudioCacheStore()

    private let context: NSManagedObjectContext
    private let audioDirectory: URL

    @Published private(set) var totalCachedBytes: Int64 = 0

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        audioDirectory = base.appendingPathComponent("VoiceCloneAAC/Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        refreshTotalBytes()
    }

    // MARK: - Paths / hashing

    private func fileURL(forTextHash textHash: String) -> URL {
        audioDirectory.appendingPathComponent("\(textHash).mp3")
    }

    func hasCached(text: String, voiceId: String) -> Bool {
        fetchCachedRow(text: text, voiceId: voiceId) != nil
    }

    func loadAudioData(text: String, voiceId: String) -> Data? {
        guard let row = fetchCachedRow(text: text, voiceId: voiceId) else { return nil }
        let url = URL(fileURLWithPath: row.localFilePath)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        row.lastUsedAt = Date()
        try? context.save()
        refreshTotalBytes()
        return data
    }

    /// Writes MP3 to disk and Core Data. Enforces 500MB LRU afterward.
    func saveAudio(data: Data, text: String, voiceId: String) throws {
        let normalized = TextHashing.normalize(text)
        let h = TextHashing.phraseHash(normalized)
        let dest = fileURL(forTextHash: h)

        if let existing = fetchCachedRow(text: normalized, voiceId: voiceId) {
            if existing.localFilePath != dest.path {
                try? FileManager.default.removeItem(atPath: existing.localFilePath)
            }
            context.delete(existing)
            try? context.save()
        }

        try data.write(to: dest, options: .atomic)

        let row = CachedAudio(context: context)
        row.text = normalized
        row.textHash = h
        row.voiceId = voiceId
        row.localFilePath = dest.path
        row.fileSize = Int64(data.count)
        let now = Date()
        row.createdAt = now
        row.lastUsedAt = now

        do {
            try context.save()
        } catch {
            try? FileManager.default.removeItem(at: dest)
            throw error
        }

        refreshTotalBytes()
        try enforceQuotaIfNeeded(excludingNormalizedTexts: Constants.quickPhraseNormalizedSet)
    }

    func touchLastUsed(text: String, voiceId: String) {
        guard let row = fetchCachedRow(text: text, voiceId: voiceId) else { return }
        row.lastUsedAt = Date()
        try? context.save()
    }

    // MARK: - Pending synthesis (offline queue)

    func enqueuePending(text: String, category: String) {
        let normalized = TextHashing.normalize(text)
        guard !normalized.isEmpty else { return }
        let p = PendingSynthesis(context: context)
        p.text = normalized
        p.category = category
        p.createdAt = Date()
        p.status = "pending"
        try? context.save()
    }

    func fetchPending() -> [PendingSynthesis] {
        let r = PendingSynthesis.fetchRequest()
        r.predicate = NSPredicate(format: "status == %@", "pending")
        r.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(r)) ?? []
    }

    func deletePending(_ p: PendingSynthesis) {
        context.delete(p)
        try? context.save()
    }

    func markPendingFailed(_ p: PendingSynthesis) {
        p.status = "failed"
        try? context.save()
    }

    // MARK: - Maintenance

    func refreshTotalBytes() {
        let r = CachedAudio.fetchRequest()
        guard let rows = try? context.fetch(r) else {
            totalCachedBytes = 0
            return
        }
        totalCachedBytes = rows.reduce(Int64(0)) { $0 + $1.fileSize }
    }

    /// Removes non–quick-phrase cache entries and their files.
    func clearHistoryKeepingQuickPhrases() throws {
        let keep = Constants.quickPhraseNormalizedSet
        let r = CachedAudio.fetchRequest()
        let rows = try context.fetch(r)
        for row in rows {
            let norm = TextHashing.normalize(row.text)
            if !keep.contains(norm) {
                try? FileManager.default.removeItem(atPath: row.localFilePath)
                context.delete(row)
            }
        }
        try context.save()
        refreshTotalBytes()
    }

    func wipeAllCachedAndPending() throws {
        let r = CachedAudio.fetchRequest()
        for row in try context.fetch(r) {
            try? FileManager.default.removeItem(atPath: row.localFilePath)
            context.delete(row)
        }
        let pr = PendingSynthesis.fetchRequest()
        for p in try context.fetch(pr) {
            context.delete(p)
        }
        try context.save()
        refreshTotalBytes()
    }

    /// Deletes cache rows whose `voiceId` does not match the active clone.
    func purgeStaleVoiceCaches(retainVoiceId: String) throws {
        let r = CachedAudio.fetchRequest()
        r.predicate = NSPredicate(format: "voiceId != %@", retainVoiceId)
        let rows = try context.fetch(r)
        for row in rows {
            try? FileManager.default.removeItem(atPath: row.localFilePath)
            context.delete(row)
        }
        try context.save()
        refreshTotalBytes()
    }

    private func fetchCachedRow(text: String, voiceId: String) -> CachedAudio? {
        let normalized = TextHashing.normalize(text)
        let h = TextHashing.phraseHash(normalized)
        let r = CachedAudio.fetchRequest()
        r.fetchLimit = 1
        r.predicate = NSPredicate(format: "textHash == %@ AND voiceId == %@", h, voiceId)
        return try? context.fetch(r).first
    }

    private func enforceQuotaIfNeeded(excludingNormalizedTexts: Set<String>) throws {
        var total = totalCachedBytes
        let limit = Constants.audioCacheMaxBytes
        guard total > limit else { return }

        let r = CachedAudio.fetchRequest()
        r.sortDescriptors = [NSSortDescriptor(key: "lastUsedAt", ascending: true)]
        let rows = try context.fetch(r)

        for row in rows where total > limit {
            let norm = TextHashing.normalize(row.text)
            if excludingNormalizedTexts.contains(norm) { continue }
            total -= row.fileSize
            try? FileManager.default.removeItem(atPath: row.localFilePath)
            context.delete(row)
        }
        try context.save()
        refreshTotalBytes()
    }
}
