import Foundation
import SwiftSoup

public class YouTubeEmbedPlugin: Plugin {
    public var name: String { return "youtube-embed" }
    public init() {}

    public func initialize(conv: Converter) throws {
        // Override iframe from .remove to .inline so YouTube iframes survive pre-render
        conv.Register.tagType("iframe", .inline, priority: PriorityEarly)

        conv.Register.rendererFor("iframe", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            let src = (try? element.attr("src")) ?? ""

            // Match youtube.com, youtu.be, youtube-nocookie.com
            guard src.contains("youtube") || src.contains("youtu.be") else { return .tryNext }

            let videoID = extractYouTubeID(from: src)
            guard !videoID.isEmpty else { return .tryNext }

            let title = (try? element.attr("title")) ?? ""
            let label = title.isEmpty ? "YouTube Video" : title
            let thumbnailURL = "https://img.youtube.com/vi/\(videoID)/0.jpg"
            let watchURL = "https://www.youtube.com/watch?v=\(videoID)"

            // Render as clickable thumbnail: [![Title](thumbnail)](watchURL)
            w.writeString("[![\(label)](\(thumbnailURL))](\(watchURL))")
            return .success
        }, priority: PriorityEarly)
    }
}

private func extractYouTubeID(from src: String) -> String {
    let cleaned = src.hasPrefix("//") ? "https:" + src : src
    guard let url = URL(string: cleaned) else { return "" }

    let path = url.path
    let components = path.split(separator: "/").map(String.init)

    // /embed/VIDEO_ID
    if let embedIdx = components.firstIndex(of: "embed"), embedIdx + 1 < components.count {
        return components[embedIdx + 1]
    }

    // youtu.be/VIDEO_ID
    if url.host?.contains("youtu.be") == true, let id = components.first, !id.isEmpty {
        return id
    }

    // v=VIDEO_ID query param
    if let queryItems = URLComponents(string: cleaned)?.queryItems,
       let v = queryItems.first(where: { $0.name == "v" })?.value {
        return v
    }

    return ""
}
