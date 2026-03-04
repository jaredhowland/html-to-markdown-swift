import Foundation
import SwiftSoup

extension ReferenceLinkPlugin {
    func registerImageRenderer(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }

            // Skip emoji images — let EmojiPlugin handle them
            if element.hasClass("emoji") { return .tryNext }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = defaultAssembleAbsoluteURL(rawSrc, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            if src.isEmpty { return .tryNext }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let rawTitle = ((try? element.attr("title")) ?? "")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            var links: [RefLink] = ctx.getState(refLinksKey) ?? []
            let idx: Int
            if let existing = links.firstIndex(where: { $0.url == src }) {
                idx = existing + 1
            } else {
                links.append(RefLink(url: src, title: rawTitle))
                idx = links.count
                ctx.setState(refLinksKey, val: links)
            }

            w.writeString("![\(rawAlt)][\(idx)]")
            return .success
        }, priority: PriorityEarly)
    }
}
