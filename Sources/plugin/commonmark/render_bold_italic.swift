import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerBoldItalicRenderers(conv: Converter) {
        for tag in ["strong", "b"] {
            conv.Register.rendererFor(tag, .inline, { [weak self] ctx, w, n in
                guard let self = self else { return .tryNext }
                let delimiter = self.options.strongDelimiter
                if let result = try? self.renderEmphasisWrappingLink(n, delimiter: delimiter, ctx: ctx) {
                    w.writeString(result); return .success
                }
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                let content = applyDelimiterPerLine(buf.string, delimiter: delimiter)
                w.writeString(content)
                return .success
            }, priority: PriorityStandard)
        }
        for tag in ["em", "i"] {
            conv.Register.rendererFor(tag, .inline, { [weak self] ctx, w, n in
                guard let self = self else { return .tryNext }
                let delimiter = self.options.emDelimiter
                if let result = try? self.renderEmphasisWrappingLink(n, delimiter: delimiter, ctx: ctx) {
                    w.writeString(result); return .success
                }
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                let content = applyDelimiterPerLine(buf.string, delimiter: delimiter)
                w.writeString(content)
                return .success
            }, priority: PriorityStandard)
        }
    }

    private func renderEmphasisWrappingLink(_ node: Node, delimiter: String, ctx: Context) throws -> String? {
        guard let element = node as? Element else { return nil }
        let nonWsChildren = element.getChildNodes().filter { child in
            if let text = child as? TextNode {
                return !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
        guard nonWsChildren.count == 1,
              let linkEl = nonWsChildren[0] as? Element,
              linkEl.tagName() == "a" else { return nil }

        let rawHref = (try? linkEl.attr("href")) ?? ""
        let href = defaultAssembleAbsoluteURL(rawHref, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)

        if href.isEmpty && options.linkEmptyHrefBehavior == .skip {
            let buf = StringWriter()
            ctx.renderChildNodes(buf, node)
            return applyDelimiterPerLine(buf.string, delimiter: delimiter)
        }

        let rawTitle = (try? linkEl.attr("title")) ?? ""
        let title = rawTitle
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        let linkBuf = StringWriter()
        ctx.renderChildNodes(linkBuf, linkEl)
        let linkContent = linkBuf.string
        let linkContentEscaped = linkContent.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")
        let trimmedContent = linkContentEscaped.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedContent.isEmpty && options.linkEmptyContentBehavior == .skip {
            return ""
        }

        let boldContent = applyDelimiterPerLine(linkContentEscaped, delimiter: delimiter)
        let trimmedBold = boldContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let leftPad = String(linkContentEscaped.prefix(while: { $0.isWhitespace }))
        let rightPad = String(linkContentEscaped.reversed().prefix(while: { $0.isWhitespace }).reversed())

        if title.isEmpty {
            return "\(leftPad)[\(trimmedBold)](\(href))\(rightPad)"
        } else {
            return "\(leftPad)[\(trimmedBold)](\(href) \(formatLinkTitle(title)))\(rightPad)"
        }
    }
}
