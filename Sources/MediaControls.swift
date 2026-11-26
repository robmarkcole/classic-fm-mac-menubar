import Combine
import MediaPlayer

@MainActor
final class MediaControls {
    private var handlers: [(MPRemoteCommand, Any)] = []
    private var subscription: AnyCancellable?

    init(radio: Radio) {
        let commands = MPRemoteCommandCenter.shared()
        register(commands.togglePlayPauseCommand) { radio.toggle() }
        register(commands.playCommand) { radio.play() }
        register(commands.pauseCommand) { radio.stop() }
        register(commands.stopCommand) { radio.stop() }

        // Claim Now Playing on first playback. Opening the app should leave the current player alone.
        subscription = radio.$active.drop(while: { !$0 }).removeDuplicates().sink { active in
            let center = MPNowPlayingInfoCenter.default()
            center.nowPlayingInfo = [
                MPMediaItemPropertyTitle: "Classic FM",
                MPNowPlayingInfoPropertyIsLiveStream: true,
                MPNowPlayingInfoPropertyPlaybackRate: active ? 1.0 : 0.0
            ]
            center.playbackState = active ? .playing : .paused
        }
    }

    private func register(_ command: MPRemoteCommand, action: @escaping @MainActor @Sendable () -> Void) {
        command.isEnabled = true
        let handler = command.addTarget { @Sendable _ in
            Task { @MainActor in action() }
            return .success
        }
        handlers.append((command, handler))
    }

    deinit {
        for (command, handler) in handlers { command.removeTarget(handler) }
    }
}
