import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject private var audioCache = AudioCacheStore.shared
    @AppStorage("vcVoiceSpeed") private var voiceSpeed = 1.0
    @AppStorage("vcTextSize") private var textSizeIndex = 1
    @AppStorage("vcHighContrast") private var highContrast = false

    @StateObject private var previewAudio = AudioService()
    @State private var previewBusy = false
    @State private var alertMessage: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("My Voice") {
                    Button("Re-record voice") {
                        auth.goToVoiceSetup()
                        dismiss()
                    }
                    .accessibilityLabel("Re-record voice clone")

                    Button("Play voice preview") {
                        Task { await playPreview() }
                    }
                    .disabled(previewBusy || auth.profile?.voiceCloneId == nil)
                    .accessibilityLabel("Play short preview with cloned voice")
                }

                Section("Voice speed") {
                    HStack {
                        Text("0.5×")
                        Slider(value: $voiceSpeed, in: 0.5 ... 2.0, step: 0.05)
                        Text("2×")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Voice playback speed")
                }

                Section("Text size") {
                    Picker("Text size", selection: $textSizeIndex) {
                        Text("Small").tag(0)
                        Text("Medium").tag(1)
                        Text("Large").tag(2)
                        Text("Extra Large").tag(3)
                    }
                    .pickerStyle(.inline)
                    .accessibilityLabel("Text size")
                }

                Section("Accessibility") {
                    Toggle("High contrast", isOn: $highContrast)
                        .accessibilityLabel("High contrast mode")
                }

                Section("Storage") {
                    LabeledContent("Cached audio") {
                        Text(byteString(audioCache.totalCachedBytes))
                    }
                    Button("Clear Cache") {
                        try? audioCache.clearHistoryKeepingQuickPhrases()
                    }
                    .accessibilityLabel("Clear cached phrase audio, keep quick phrases")
                    Text("Removes cached history phrases. Quick phrases stay for offline use.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Account") {
                    if let name = auth.profile?.displayName, !name.isEmpty {
                        LabeledContent("Name", value: name)
                    }
                    if let id = auth.profile?.id.uuidString.prefix(8) {
                        Text("Account id: \(id)…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Sign out", role: .destructive) {
                        auth.signOut()
                        dismiss()
                    }
                    .accessibilityLabel("Sign out")
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    Link("Privacy policy", destination: URL(string: "https://example.com/privacy")!)
                        .accessibilityLabel("Open privacy policy")
                    LabeledContent("Support") {
                        Link("support@voiceclone.app", destination: URL(string: "mailto:support@voiceclone.app")!)
                    }
                }

                Section {
                    Button("Delete account", role: .destructive) {
                        showDeleteConfirm = true
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Delete account and local data")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Preview failed", isPresented: .init(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
            .confirmationDialog(
                "Delete account?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete local data & sign out", role: .destructive) {
                    KeychainHelper.deleteToken()
                    try? audioCache.wipeAllCachedAndPending()
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the app session from this device. Contact support to remove server data.")
            }
        }
        .onAppear {
            audioCache.refreshTotalBytes()
        }
    }

    private func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    @MainActor
    private func playPreview() async {
        previewBusy = true
        defer { previewBusy = false }
        do {
            let data = try await APIService.shared.synthesizeSpeech(
                text: Constants.postClonePreviewText,
                voiceId: nil,
                phraseId: nil
            )
            previewAudio.playbackRate = Float(voiceSpeed)
            try previewAudio.play(data: data)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
