import SwiftUI

struct PlayerPopover: View {
    @ObservedObject var radio: Radio
    @ObservedObject var feed: StationFeed
    let visible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Classic FM").font(.headline)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.controlSize(.small)
            }
            HStack(alignment: .center, spacing: 14) {
                AsyncImage(url: feed.card?.artwork) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "music.note").font(.title).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84).clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(feed.card?.heading ?? "Station playlist").font(.caption).foregroundStyle(.secondary)
                    Text(feed.card?.title ?? (feed.unavailable ? "Details unavailable" : "Loading…"))
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    if let composer = feed.card?.composer {
                        Text(composer).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Divider()
            HStack {
                Button(action: radio.toggle) {
                    Label(radio.active ? "Stop" : "Play", systemImage: radio.active ? "stop.fill" : "play.fill")
                }
                Text(radio.status).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16).frame(width: 330)
        .task(id: visible) {
            guard visible else { return }
            await feed.refreshWhileVisible()
        }
    }
}

@MainActor
final class StationFeed: ObservableObject {
    @Published private(set) var card: StationCard?
    @Published private(set) var unavailable = false

    func refreshWhileVisible() async {
        let url = URL(string: "https://www.classicfm.com/dynamic/now-playing-card/")!
        while !Task.isCancelled {
            do {
                let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let refreshed = try StationCard(html: data)
                try Task.checkCancellation()
                card = refreshed
                unavailable = false
            } catch {
                guard !Task.isCancelled else { return }
                card = nil
                unavailable = true
            }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
}
