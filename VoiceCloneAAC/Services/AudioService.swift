import AVFoundation
import Foundation

@MainActor
final class AudioService: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var meterLevel: Float = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var player: AVAudioPlayer?

    var playbackRate: Float = 1.0 {
        didSet {
            playbackRate = min(2, max(0.5, playbackRate))
            player?.enableRate = true
            player?.rate = playbackRate
        }
    }

    override init() {
        super.init()
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    func prepareRecordingSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    func preparePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)
    }

    func startRecording(to url: URL) throws {
        try prepareRecordingSession()

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let r = try AVAudioRecorder(url: url, settings: settings)
        r.isMeteringEnabled = true
        r.prepareToRecord()
        guard r.record() else { throw AudioError.recordFailed }
        recorder = r
        isRecording = true

        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let rec = self.recorder, rec.isRecording else { return }
                rec.updateMeters()
                let power = rec.averagePower(forChannel: 0)
                let norm = max(0, min(1, (power + 50) / 50))
                self.meterLevel = norm
            }
        }
    }

    func stopRecording() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        isRecording = false
        meterLevel = 0
    }

    func play(url: URL) throws {
        try preparePlaybackSession()
        stopPlayback()
        let p = try AVAudioPlayer(contentsOf: url)
        p.enableRate = true
        p.rate = playbackRate
        p.prepareToPlay()
        guard p.play() else { throw AudioError.playFailed }
        player = p
    }

    func play(data: Data) throws {
        try preparePlaybackSession()
        stopPlayback()
        let p = try AVAudioPlayer(data: data)
        p.enableRate = true
        p.rate = playbackRate
        p.prepareToPlay()
        guard p.play() else { throw AudioError.playFailed }
        player = p
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }

    enum AudioError: Error {
        case recordFailed
        case playFailed
    }
}
