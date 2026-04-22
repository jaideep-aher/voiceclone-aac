import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class VoiceSetupViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case recorded
        case processing
        case previewSuccess
        case error(String)
    }

    @Published var phase: Phase = .idle
    @Published var waveformSamples: [CGFloat] = Array(repeating: 0.12, count: 40)
    @Published private(set) var lastClonedVoiceId: String?

    private let api = APIService.shared
    private let audio = AudioService()
    private var recordingURL: URL?

    var audioService: AudioService { audio }

    func updateWaveform(from level: Float) {
        var next = waveformSamples
        next.removeFirst()
        next.append(CGFloat(level))
        waveformSamples = next
    }

    func resetWaveform() {
        waveformSamples = Array(repeating: 0.12, count: 40)
    }

    func recordingFileURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("voice-sample-\(UUID().uuidString).m4a")
    }

    func requestPermission() async -> Bool {
        await audio.requestMicrophonePermission()
    }

    func startRecording() {
        let url = recordingFileURL()
        recordingURL = url
        resetWaveform()
        do {
            try audio.startRecording(to: url)
            phase = .recording
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func stopRecording() {
        audio.stopRecording()
        if recordingURL != nil {
            phase = .recorded
        }
    }

    func discardRecording() {
        if let u = recordingURL {
            try? FileManager.default.removeItem(at: u)
        }
        recordingURL = nil
        phase = .idle
    }

    func playRecording() {
        guard let url = recordingURL else { return }
        do {
            try audio.play(url: url)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func uploadAndClone() async throws {
        guard let url = recordingURL else { return }
        phase = .processing
        do {
            let result = try await api.cloneVoice(fileURL: url, mimeType: "audio/mp4")
            lastClonedVoiceId = result.voiceId
            phase = .previewSuccess
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .error(msg)
            throw error
        }
    }

    func cloneFromPickedFile(_ url: URL) async throws {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        phase = .processing
        recordingURL = url
        do {
            let result = try await api.cloneVoice(fileURL: url, mimeType: mimeForFile(url))
            lastClonedVoiceId = result.voiceId
            phase = .previewSuccess
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            phase = .error(msg)
            throw error
        }
    }

    private func mimeForFile(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4", "aac": return "audio/mp4"
        default: return "application/octet-stream"
        }
    }

    func playPreviewTTS() async throws {
        let data = try await api.synthesizeSpeech(
            text: Constants.postClonePreviewText,
            voiceId: nil,
            phraseId: nil
        )
        if let vid = lastClonedVoiceId {
            try? AudioCacheStore.shared.saveAudio(
                data: data,
                text: Constants.postClonePreviewText,
                voiceId: vid
            )
        }
        try audio.play(data: data)
    }

    func resetAfterError() {
        discardRecording()
        phase = .idle
    }
}
