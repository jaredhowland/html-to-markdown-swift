import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerBoldItalicRenderers(converter: Converter) {
        for tag in ["strong", "b"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                guard let self = self else { return nil }
                let delimiter = self.options.strongDelimiter
                if let result = try self.renderEmphasisWrappingLink(node, delimiter: delimiter, converter: converter) {
                    return result
                }
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
        for tag in ["em", "i"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                guard let self = self else { return nil }
                let delimiter = self.options.emDelimiter
                if let result = try self.renderEmphasisWrappingLink(node, delimiter: delimiter, converter: converter) {
                    return result
                }
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
    }

    /// SwapTags(bold/italic, link): if the sole non-whitespace child is an `<a>`, render as
    /// `[**content**](href)` instead of `**[content](href)**`.
    private func renderEmphasisWrappingLink(_ node: Node, delimiter: String, converter: Converter) throws -> String? {
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
        let href = assembleAbsoluteURL(rawHref, domain: converter.getOptions().baseDomain)

        if href.isEmpty && options.linkEmptyHrefBehavior == .skip {
            let content = try renderChildren(node, converter: converter)
            return applyDelimiterPerLine(content, delimiter: delimiter)
        }

        let rawTitle = (try? linkEl.attr("title")) ?? ""
        let title = rawTitle
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        let linkContent = try renderChildren(linkEl, converter: converter)
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
