import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let radio = Radio()
    private var mediaControls: MediaControls?
    private let feed = StationFeed()
    private let popover = NSPopover()
    private var item: NSStatusItem!
    private var subscription: AnyCancellable?
    private let play = NSButton()
    private lazy var panel = NSHostingController(rootView: PlayerPopover(radio: radio, feed: feed, visible: false))

    func applicationDidFinishLaunching(_ notification: Notification) {
        mediaControls = MediaControls(radio: radio)
        item = NSStatusBar.system.statusItem(withLength: 65)
        guard let button = item.button else { return }
        button.title = "FM ▾ "
        button.alignment = .right
        button.target = self
        button.action = #selector(showDetails)
        button.toolTip = "Classic FM · Show station details"
        button.setAccessibilityLabel("Show Classic FM station details")

        play.isBordered = false
        play.imagePosition = .imageOnly
        play.frame = NSRect(x: 1, y: 0, width: 26, height: button.bounds.height)
        play.autoresizingMask = [.height]
        play.target = self
        play.action = #selector(toggle)
        button.addSubview(play)
        subscription = radio.$active.sink { [weak self] active in
            let label = active ? "Stop Classic FM" : "Play Classic FM"
            self?.play.image = NSImage(systemSymbolName: active ? "stop.fill" : "play.fill", accessibilityDescription: label)
            self?.play.toolTip = label
            self?.play.setAccessibilityLabel(label)
        }
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = panel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.absoluteString == "classicfmradio://toggle" {
            toggle()
        }
    }

    @objc private func toggle() { radio.toggle() }

    @objc private func showDetails() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = item.button {
            panel.rootView = PlayerPopover(radio: radio, feed: feed, visible: true)
            popover.contentSize = panel.view.fittingSize
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        panel.rootView = PlayerPopover(radio: radio, feed: feed, visible: false)
    }
}

@main
struct ClassicFMApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
