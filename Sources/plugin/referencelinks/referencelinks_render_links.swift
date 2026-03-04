import Foundation
import SwiftSoup

extension ReferenceLinkPlugin {
    func registerLinkRenderer(conv: Converter) {
        conv.Register.rendererFor("a", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }

            let rawHref = (try? element.attr("href")) ?? ""
            let href = defaultAssembleAbsoluteURL(rawHref, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)

            // Skip empty hrefs — let CommonmarkPlugin handle per its configuration
            if href.isEmpty { return .tryNext }

            let rawTitle = ((try? element.attr("title")) ?? "")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            let content = buf.string

            let leftPad = String(content.prefix(while: { $0.isWhitespace }))
            let innerRaw = String(content.drop(while: { $0.isWhitespace }))
            let rightPad = String(innerRaw.reversed().prefix(while: { $0.isWhitespace }).reversed())
            let inner = String(innerRaw.dropLast(rightPad.count))

            if inner.isEmpty { return .tryNext }

            // Collect link, assign number
            var links: [RefLink] = ctx.getState(refLinksKey) ?? []
            let idx: Int
            if let existing = links.firstIndex(where: { $0.url == href }) {
                idx = existing + 1
            } else {
                links.append(RefLink(url: href, title: rawTitle))
                idx = links.count
                ctx.setState(refLinksKey, val: links)
            }

            w.writeString("\(leftPad)[\(inner)][\(idx)]\(rightPad)")
            return .success
        }, priority: PriorityEarly)
    }
}
