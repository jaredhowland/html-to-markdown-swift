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

    /// Assemble an absolute URL from a raw href and optional base domain.
    /// Matches Go's defaultAssembleAbsoluteURL logic.
    func assembleAbsoluteURL(_ rawURL: String, domain: String?) -> String {
        var url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if url == "#" { return url }

        url = url.replacingOccurrences(of: "\n", with: "%0A")
        url = url.replacingOccurrences(of: "\t", with: "%09")

        if let domain = domain, !domain.isEmpty {
            if let baseURL = parseBaseDomain(domain) {
                let urlForParsing = url.replacingOccurrences(of: " ", with: "%20")
                if let relURL = URL(string: urlForParsing, relativeTo: baseURL) {
                    url = relURL.absoluteString
                } else if !url.hasPrefix("http") && !url.contains(":") {
                    let base = domain.hasSuffix("/") ? String(domain.dropLast()) : domain
                    let path = url.hasPrefix("/") ? url : "/" + url
                    url = base + path
                }
            }
        }

        url = url.replacingOccurrences(of: " ", with: "%20")
        url = url.replacingOccurrences(of: "[", with: "%5B")
        url = url.replacingOccurrences(of: "]", with: "%5D")
        url = url.replacingOccurrences(of: "(", with: "%28")
        url = url.replacingOccurrences(of: ")", with: "%29")
        url = url.replacingOccurrences(of: "<", with: "%3C")
        url = url.replacingOccurrences(of: ">", with: "%3E")
        return url
    }

    private func parseBaseDomain(_ rawDomain: String) -> URL? {
        if rawDomain.isEmpty { return nil }
        if let url = URL(string: rawDomain), url.host != nil { return url }
        if let url = URL(string: "http://" + rawDomain), url.host != nil { return url }
        return nil
    }

    func registerLinkRenderers(converter: Converter) {
        converter.registerRenderer("a") { [weak self] node, converter in
            guard let element = node as? Element else { return nil }
            guard let self = self else { return nil }

            let rawHref = (try? element.attr("href")) ?? ""
            let href = self.assembleAbsoluteURL(rawHref, domain: converter.getOptions().baseDomain)

            if href.isEmpty && self.options.linkEmptyHrefBehavior == .skip {
                return try renderChildren(node, converter: converter)
            }

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            var effectiveTitle = title
            if href.isEmpty { effectiveTitle = "" }

            let content = try renderChildren(node, converter: converter)
            let contentEscaped = content.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")

            let leftPad = String(contentEscaped.prefix(while: { $0.isWhitespace }))
            let withoutLeft = String(contentEscaped.drop(while: { $0.isWhitespace }))
            let rightPad = String(withoutLeft.reversed().prefix(while: { $0.isWhitespace }).reversed())
            var innerContent = String(withoutLeft.dropLast(rightPad.count))

            if innerContent.isEmpty && self.options.linkEmptyContentBehavior == .skip {
                return ""
            }

            innerContent = trimConsecutiveNewlines(innerContent)
            innerContent = escapeMultiLine(innerContent)

            if effectiveTitle.isEmpty {
                return "\(leftPad)[\(innerContent)](\(href))\(rightPad)"
            } else {
                return "\(leftPad)[\(innerContent)](\(href) \(self.formatLinkTitle(effectiveTitle)))\(rightPad)"
            }
        }
    }
}
