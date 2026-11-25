import AppKit
import Carbon

@MainActor
final class MusicPlayback {
    static let preferenceKey = "pauseMusicWhenStartingClassicFM"
    private var playbackObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var wasPlaying = false

    init(onStart: @escaping @MainActor () -> Void) {
        let center = DistributedNotificationCenter.default()
        let name = Notification.Name("com.apple.Music.playerInfo")
        playbackObserver = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                guard let self, let state = note.userInfo?["Player State"] as? String else { return }
                let playing = state == "Playing"
                if playing && !self.wasPlaying { onStart() }
                self.wasPlaying = playing
            }
        }
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated {
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                if app?.bundleIdentifier == "com.apple.Music" { self?.wasPlaying = false }
            }
        }
    }

    deinit {
        if let playbackObserver { DistributedNotificationCenter.default().removeObserver(playbackObserver) }
        if let terminationObserver { NSWorkspace.shared.notificationCenter.removeObserver(terminationObserver) }
    }

    // Address the running process so a handoff can never launch Music.
    static func pause(_ app: NSRunningApplication) async throws {
        let pid = app.processIdentifier
        // Music.sdef defines its pause command as the Apple event 'hook'/'Paus'.
        let eventClass: AEEventClass = 0x686F6F6B
        let eventID: AEEventID = 0x50617573
        let permission = await Task.detached {
            let target = NSAppleEventDescriptor(processIdentifier: pid)
            return AEDeterminePermissionToAutomateTarget(target.aeDesc, eventClass, eventID, true)
        }.value
        try Task.checkCancellation()
        guard !app.isTerminated else { return }
        guard permission == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(permission)) }
        let event = NSAppleEventDescriptor(eventClass: eventClass, eventID: eventID,
                                           targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        _ = try event.sendEvent(options: [.noReply, .neverInteract], timeout: 1)
    }
}
