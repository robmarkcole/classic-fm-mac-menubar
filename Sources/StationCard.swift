import Foundation

struct StationCard: Equatable {
    let heading: String
    let title: String
    let composer: String?
    let artwork: URL?

    init(html: Data) throws {
        // Foundation's HTML tidy pass discards HTML5 article elements and their attributes.
        let markup = String(decoding: html, as: UTF8.self).replacingOccurrences(
            of: #"<(/?)article\b"#, with: "<$1div", options: [.regularExpression, .caseInsensitive])
        let document = try XMLDocument(xmlString: markup, options: [.documentTidyHTML, .nodeLoadExternalEntitiesNever])
        let top = "//*[contains(concat(' ', normalize-space(@class), ' '), ' card_top_track ')]"
        guard let article = try document.nodes(forXPath: top).first else { throw URLError(.cannotParseResponse) }

        func field(_ path: String) throws -> String? {
            let raw = try article.nodes(forXPath: path).first?.stringValue
            let value = raw?.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            return value?.isEmpty == false ? value : nil
        }
        guard let title = try field(".//*[@itemprop='name']") else { throw URLError(.cannotParseResponse) }
        self.title = title
        heading = try field(".//*[local-name()='h2']") ?? "Station playlist"
        composer = try field(".//*[@itemprop='byArtist']")
        let url = try field(".//*[local-name()='img'][@itemprop='image']/@src").flatMap(URL.init(string:))
        artwork = url?.scheme == "https" ? url : nil
    }
}
