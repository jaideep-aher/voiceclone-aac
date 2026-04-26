import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var homeVM = HomeViewModel()
    @ObservedObject private var network = NetworkMonitor.shared
    @ObservedObject private var audioCache = AudioCacheStore.shared
    @State private var showSettings = false
    @State private var showAddPhrase = false
    @State private var newPhraseText = ""
    @State private var newPhraseCategory = "Custom"
    @State private var showBackOnlineToast = false

    @AppStorage("vcVoiceSpeed") private var voiceSpeed = 1.0
    @AppStorage("vcTextSize") private var textSizeIndex = 1
    @AppStorage("vcHighContrast") private var highContrast = false

    private var voiceId: String? { auth.profile?.voiceCloneId }

    private var draftOfflineHint: String? {
        let t = homeVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !network.isConnected else { return nil }
        guard !homeVM.isTextCached(t, voiceId: voiceId) else { return nil }
        return "Will synthesize when back online"
    }

    private var speakDisabled: Bool {
        let t = homeVM.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }                          // nothing to speak
        if network.isConnected { return false }
        return !homeVM.isTextCached(t, voiceId: voiceId)     // offline + not cached
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    if !network.isConnected {
                        Text("Offline — cached phrases available")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.22))
                            .accessibilityLabel("Offline. Cached phrases available.")
                    }

                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                TextInputView(text: $homeVM.draftText, offlineHint: draftOfflineHint)
                                    .padding(.top, 8)

                                SpeakButton(
                                    title: "Speak",
                                    isLoading: homeVM.isSpeaking,
                                    isDisabled: speakDisabled
                                ) {
                                    Task {
                                        await homeVM.speak(
                                            homeVM.draftText,
                                            phraseId: nil,
                                            voiceId: voiceId,
                                            categoryForQueue: "custom",
                                            onUnauthorized: { auth.handleUnauthorized() }
                                        )
                                    }
                                }

                                QuickPhrasesView(
                                    phrases: Constants.defaultQuickPhrases,
                                    highContrast: highContrast,
                                    isPhraseCached: { homeVM.isTextCached($0, voiceId: voiceId) }
                                ) { text in
                                    Task {
                                        await homeVM.speak(
                                            text,
                                            phraseId: nil,
                                            voiceId: voiceId,
                                            categoryForQueue: "quick",
                                            onUnauthorized: { auth.handleUnauthorized() }
                                        )
                                    }
                                }

                                categoryChips

                                RecentPhrasesView(
                                    phrases: homeVM.searchQuery.isEmpty ? homeVM.recentPhrases : homeVM.searchResults,
                                    sectionTitle: homeVM.searchQuery.isEmpty ? "Recent" : "Results",
                                    highContrast: highContrast,
                                    cacheCaption: { homeVM.cacheStatusLabel(for: $0.text, voiceId: voiceId) },
                                    onSpeak: { phrase in
                                        Task {
                                            await homeVM.speak(
                                                phrase.text,
                                                phraseId: phrase.id,
                                                voiceId: voiceId,
                                                categoryForQueue: "library",
                                                onUnauthorized: { auth.handleUnauthorized() }
                                            )
                                        }
                                    },
                                    onDelete: { phrase in
                                        Task { await homeVM.deletePhrase(phrase) }
                                    }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 100)
                        }

                        Button {
                            newPhraseText = ""
                            newPhraseCategory = "Custom"
                            showAddPhrase = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(Color.vcPrimary))
                                .shadow(color: .vcCardShadow, radius: 4, y: 2)
                        }
                        .padding(24)
                        .accessibilityLabel("Add phrase to library")
                    }
                }

                if showBackOnlineToast {
                    Text("Back online")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.top, network.isConnected ? 48 : 96)
                        .accessibilityLabel("Back online")
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .background(highContrast ? Color.white : Color.vcBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if homeVM.isPlayingAudio {
                        Button {
                            homeVM.stopSpeaking()
                        } label: {
                            Image(systemName: "stop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.red)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Stop speaking")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("VoiceClone")
                        .font(.headline)
                        .foregroundStyle(Color.vcPrimary)
                        .accessibilityHidden(true)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(Color.vcPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showAddPhrase) {
                NavigationStack {
                    Form {
                        TextField("Phrase", text: $newPhraseText, axis: .vertical)
                            .lineLimit(3 ... 6)
                        Picker("Category", selection: $newPhraseCategory) {
                            ForEach(Constants.phraseCategories, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                    }
                    .navigationTitle("New phrase")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAddPhrase = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    do {
                                        try await homeVM.addPhrase(
                                            text: newPhraseText,
                                            category: newPhraseCategory
                                        )
                                        showAddPhrase = false
                                    } catch {
                                        homeVM.lastError = error.localizedDescription
                                    }
                                }
                            }
                            .disabled(newPhraseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .searchable(text: $homeVM.searchQuery, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search phrases…")
        .dynamicTypeSize(dynamicTypeSize)
        .animation(.easeInOut(duration: 0.2), value: showBackOnlineToast)
        .task {
            homeVM.bindPlaybackRate(Float(voiceSpeed))
            await homeVM.loadPhrases()
            await auth.refreshProfile()
        }
        .onChange(of: voiceSpeed) { _, v in
            homeVM.bindPlaybackRate(Float(v))
        }
        .onChange(of: network.isConnected) { _, online in
            if online {
                Task {
                    await homeVM.processPendingQueue(voiceId: voiceId)
                    await homeVM.loadPhrases()
                }
                withAnimation {
                    showBackOnlineToast = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation {
                        showBackOnlineToast = false
                    }
                }
            }
        }
        .alert("Something went wrong", isPresented: .init(
            get: { homeVM.lastError != nil },
            set: { if !$0 { homeVM.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { homeVM.lastError = nil }
        } message: {
            Text(homeVM.lastError ?? "")
        }
        .alert("Offline", isPresented: .init(
            get: { homeVM.offlineInfoMessage != nil },
            set: { if !$0 { homeVM.offlineInfoMessage = nil } }
        )) {
            Button("OK", role: .cancel) { homeVM.offlineInfoMessage = nil }
        } message: {
            Text(homeVM.offlineInfoMessage ?? "")
        }
    }

    private var dynamicTypeSize: DynamicTypeSize {
        switch textSizeIndex {
        case 0: return .small
        case 1: return .medium
        case 2: return .large
        default: return .xLarge
        }
    }

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)
                .foregroundStyle(Color.vcPrimary)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    categoryChip("All", selected: homeVM.selectedCategory == nil) {
                        homeVM.setCategory(nil)
                    }
                    ForEach(Constants.phraseCategories, id: \.self) { cat in
                        categoryChip(cat, selected: homeVM.selectedCategory == cat) {
                            homeVM.setCategory(cat)
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(selected ? Color.vcPrimary : Color.white)
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
                .shadow(color: highContrast ? .clear : .vcCardShadow, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Category \(title)")
        .frame(minHeight: 44)
    }
}
