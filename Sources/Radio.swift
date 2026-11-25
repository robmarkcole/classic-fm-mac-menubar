import AppKit
import AVFoundation
import Combine
import OSLog

@MainActor
final class Radio: ObservableObject {
    @Published private(set) var active = false
    private let log = Logger(subsystem: "com.robmarkcole.classic-fm-menubar", category: "playback")
    @Published private(set) var status = "Stopped" {
        didSet {
            if oldValue != status { log.info("\(self.status, privacy: .public)") }
        }
    }
    @Published private(set) var musicNotice: String?
    @Published var pauseMusic: Bool {
        didSet {
            UserDefaults.standard.set(pauseMusic, forKey: MusicPlayback.preferenceKey)
            if !pauseMusic {
                musicNotice = nil
                if pendingStart != nil {
                    pendingStart?.cancel()
                    pendingStart = nil
                    startStream()
                }
            }
        }
    }
    private var musicPlayback: MusicPlayback?
    private var pendingStart: Task<Void, Never>?

    init() {
        UserDefaults.standard.register(defaults: [MusicPlayback.preferenceKey: true])
        pauseMusic = UserDefaults.standard.bool(forKey: MusicPlayback.preferenceKey)
        musicPlayback = MusicPlayback { [weak self] in
            guard let self, self.active else { return }
            self.stop("Stopped because Music started")
        }
    }

    private var player: AVPlayer?
    private var observations: [NSKeyValueObservation] = []
    private var endObservers: [NSObjectProtocol] = []

    func toggle() {
        if active {
            stop("Stopped")
            return
        }
        active = true
        musicNotice = nil
        guard pauseMusic, let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first else {
            startStream()
            return
        }
        status = "Switching from Music…"
        pendingStart = Task {
            do {
                try Task.checkCancellation()
                try await MusicPlayback.pause(music)
            } catch {
                guard !Task.isCancelled else { return }
                musicNotice = "Couldn’t pause Music. You can pause it manually."
            }
            guard !Task.isCancelled else { return }
            pendingStart = nil
            startStream()
        }
    }

    private func startStream() {
        let item = AVPlayerItem(url: URL(string: "https://media-ssl.musicradio.com/ClassicFMMP3")!)
        let next = AVPlayer(playerItem: item)
        player = next
        status = "Connecting…"
        observations = [
            next.observe(\.timeControlStatus, options: [.new]) { [weak self, weak next] _, _ in
                Task { @MainActor in
                    guard let self, let next, self.player === next else { return }
                    self.status = next.timeControlStatus == .playing ? "Playing live" : "Buffering…"
                }
            },
            item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                Task { @MainActor in
                    guard let self, self.player?.currentItem === item, item.status == .failed else { return }
                    self.stop("Stream unavailable · Press play to retry")
                }
            }
        ]
        endObservers = [AVPlayerItem.didPlayToEndTimeNotification, AVPlayerItem.failedToPlayToEndTimeNotification].map { name in
            NotificationCenter.default.addObserver(forName: name, object: item, queue: .main) { [weak self, weak item] _ in
                Task { @MainActor in
                    guard let self, let item, self.player?.currentItem === item else { return }
                    self.stop("Stream ended · Press play to retry")
                }
            }
        }
        next.play()
    }

    private func stop(_ message: String) {
        pendingStart?.cancel()
        pendingStart = nil
        musicNotice = nil
        observations.removeAll()
        endObservers.forEach(NotificationCenter.default.removeObserver)
        endObservers.removeAll()
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        active = false
        status = message
    }
}
