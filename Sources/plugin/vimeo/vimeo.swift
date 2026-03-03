import Foundation
import SwiftSoup

public class VimeoEmbedPlugin: Plugin {
    public var name: String { return "vimeo-embed" }
    public init() {}

    public func initialize(conv: Converter) throws {
        // Override iframe from .remove to .inline so Vimeo iframes survive pre-render
        conv.Register.tagType("iframe", .inline, priority: PriorityEarly)

        conv.Register.rendererFor("iframe", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            let src = (try? element.attr("src")) ?? ""

            // Match player.vimeo.com/video/ID or vimeo.com/video/ID
            guard src.contains("vimeo.com") else { return .tryNext }

            // Extract video ID from URL path like /video/123456789
            let videoID = extractVimeoID(from: src)
            guard !videoID.isEmpty else { return .tryNext }

            let title = (try? element.attr("title")) ?? ""
            let label = title.isEmpty ? "Vimeo Video" : title

            w.writeString("[\(label)](https://vimeo.com/\(videoID))")
            return .success
        }, priority: PriorityEarly)
    }
}

private func extractVimeoID(from src: String) -> String {
    // Handles: https://player.vimeo.com/video/123456789
    // and: https://player.vimeo.com/video/123456789?h=abc&autopause=0
    guard let url = URL(string: src) else {
        // Try regex fallback for protocol-relative URLs like //player.vimeo.com/...
        let cleaned = src.hasPrefix("//") ? "https:" + src : src
        guard let url2 = URL(string: cleaned) else { return "" }
        return extractVimeoIDFromPath(url2.path)
    }
    return extractVimeoIDFromPath(url.path)
}

private func extractVimeoIDFromPath(_ path: String) -> String {
    let components = path.split(separator: "/").map(String.init)
    // Path is like /video/123456789 → ["video", "123456789"]
    if let videoIdx = components.firstIndex(of: "video"), videoIdx + 1 < components.count {
        return components[videoIdx + 1]
    }
    // Fallback: last numeric component
    return components.last(where: { $0.allSatisfy(\.isNumber) }) ?? ""
}
