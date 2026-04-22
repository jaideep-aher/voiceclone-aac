import SwiftUI
import UniformTypeIdentifiers

struct VoiceSetupView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var vm = VoiceSetupViewModel()
    @ObservedObject private var preCache = PreCacheCoordinator.shared
    @State private var secondsLeft = Int(Constants.maxRecordingSeconds)
    @State private var recordTimer: Timer?
    @State private var showImporter = false
    @State private var localError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Let's Capture Your Voice")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.vcPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(Constants.samplePhraseForRecording)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .accessibilityLabel("Text to read aloud")

                ZStack {
                    WaveformView(samples: vm.waveformSamples)
                        .frame(height: 72)
                        .opacity(vm.phase == .recording ? 1 : 0.35)
                }

                HStack {
                    Spacer()
                    if vm.phase == .recording {
                        Text("\(secondsLeft)s")
                            .font(.title2.monospacedDigit().bold())
                            .foregroundStyle(Color.red)
                            .accessibilityLabel("\(secondsLeft) seconds remaining")
                    }
                    Spacer()
                }

                if vm.phase == .idle || vm.phase == .recording {
                    Button {
                        Task { await toggleRecord() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(vm.phase == .recording ? Color.red : Color.vcPrimary)
                                .frame(width: 88, height: 88)
                                .shadow(color: .vcCardShadow, radius: 4, y: 2)
                            Image(systemName: vm.phase == .recording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(vm.phase == .recording ? "Stop recording" : "Start recording")
                    .accessibilityHint("Records up to 15 seconds of your voice")
                }

                if vm.phase == .recorded {
                    HStack(spacing: 16) {
                        Button("Play back") { vm.playRecording() }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Play back recording")

                        Button("Try Again") { vm.discardRecording(); secondsLeft = Int(Constants.maxRecordingSeconds) }
                            .buttonStyle(.borderedProminent)
                            .tint(.vcPrimary)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Discard and try again")

                        Button("Use This Voice") { Task { await submitClone() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.vcAccentTeal)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Upload and create voice clone")
                    }
                    .frame(maxWidth: .infinity)
                }

                Button("Or upload an existing recording") { showImporter = true }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.vcPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel("Upload an existing recording")

                if case .processing = vm.phase {
                    VStack(spacing: 12) {
                        ProgressView("Creating your voice clone…")
                            .accessibilityLabel("Creating your voice clone")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if case .previewSuccess = vm.phase {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your clone is ready. Listen to a quick preview.")
                            .font(.headline)
                        if let prog = preCache.progress {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Preparing your phrases... \(prog.done)/\(prog.total)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                ProgressView(value: Double(prog.done), total: Double(prog.total))
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Preparing offline quick phrases, \(prog.done) of \(prog.total)")
                        }
                        Button("Play preview") {
                            Task {
                                do { try await vm.playPreviewTTS() }
                                catch { localError = error.localizedDescription }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.vcPrimary)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Play preview with cloned voice")

                        Button("Sounds Great!") {
                            auth.voiceSetupCompleted()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.vcAccentTeal)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Continue to home")
                    }
                    .padding(.top, 8)
                }

                if case .error(let msg) = vm.phase {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(msg)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .accessibilityLabel(msg)
                        Button("Try again") {
                            vm.resetAfterError()
                            localError = nil
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.vcPrimary)
                        .accessibilityLabel("Try voice setup again")
                    }
                }

                if let localError {
                    Text(localError)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
            .padding(24)
        }
        .background(Color.vcBackground.ignoresSafeArea())
        .onReceive(Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()) { _ in
            guard vm.phase == .recording else { return }
            vm.updateWaveform(from: vm.audioService.meterLevel)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio, .mpeg4Audio, UTType(filenameExtension: "mp3") ?? .audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .failure(let err):
                localError = err.localizedDescription
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    do {
                        try await vm.cloneFromPickedFile(url)
                    } catch {
                        localError = error.localizedDescription
                    }
                }
            }
        }
        .task {
            _ = await vm.requestPermission()
        }
        .onChange(of: vm.phase) { _, newPhase in
            guard newPhase == .previewSuccess, let vid = vm.lastClonedVoiceId else { return }
            try? AudioCacheStore.shared.purgeStaleVoiceCaches(retainVoiceId: vid)
            preCache.startQuickPhrasesPrecache(voiceId: vid)
        }
    }

    private func toggleRecord() async {
        localError = nil
        if vm.phase == .recording {
            stopTimer()
            vm.stopRecording()
            return
        }
        if vm.phase == .idle || vm.phase == .recorded {
            if vm.phase == .recorded { vm.discardRecording() }
            secondsLeft = Int(Constants.maxRecordingSeconds)
            vm.startRecording()
            guard vm.phase == .recording else { return }
            startTimer()
        }
    }

    private func startTimer() {
        stopTimer()
        recordTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsLeft > 1 {
                secondsLeft -= 1
            } else {
                stopTimer()
                vm.stopRecording()
            }
        }
    }

    private func stopTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
    }

    private func submitClone() async {
        localError = nil
        do {
            try await vm.uploadAndClone()
        } catch {
            localError = error.localizedDescription
        }
    }
}
