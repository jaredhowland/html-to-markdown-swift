import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func formatLinkTitle(_ title: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let hasDouble = normalized.contains("\"")
        let hasSingle = normalized.contains("'")
        if hasDouble && hasSingle {
            let escaped = normalized.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        if hasDouble {
            return "'\(normalized)'"
        }
        return "\"\(normalized)\""
    }


    func registerLinkRenderers(conv: Converter) {
        conv.Register.rendererFor("a", .inline, { [weak self] ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard let self = self else { return .tryNext }

            let rawHref = (try? element.attr("href")) ?? ""
            let href = defaultAssembleAbsoluteURL(rawHref, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)

            if href.isEmpty && self.options.linkEmptyHrefBehavior == .skip {
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                w.writeString(buf.string)
                return .success
            }

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            var effectiveTitle = title
            if href.isEmpty { effectiveTitle = "" }

            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            let content = buf.string
            let contentEscaped = content.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")

            let leftPad = String(contentEscaped.prefix(while: { $0.isWhitespace }))
            let withoutLeft = String(contentEscaped.drop(while: { $0.isWhitespace }))
            let rightPad = String(withoutLeft.reversed().prefix(while: { $0.isWhitespace }).reversed())
            var innerContent = String(withoutLeft.dropLast(rightPad.count))

            if innerContent.isEmpty && self.options.linkEmptyContentBehavior == .skip {
                w.writeString("")
                return .success
            }

            innerContent = trimConsecutiveNewlines(innerContent)
            innerContent = escapeMultiLine(innerContent)

            if effectiveTitle.isEmpty {
                w.writeString("\(leftPad)[\(innerContent)](\(href))\(rightPad)")
            } else {
                w.writeString("\(leftPad)[\(innerContent)](\(href) \(self.formatLinkTitle(effectiveTitle)))\(rightPad)")
            }
            return .success
        }, priority: PriorityStandard)
    }
}
