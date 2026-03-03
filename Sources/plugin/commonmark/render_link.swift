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
    /// Matches Go's defaultAssembleAbsoluteURL logic exactly.
    func assembleAbsoluteURL(_ rawURL: String, domain: String?) -> String {
        var url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if url == "#" { return url }

        // Increase the chance that the URL will parse correctly (matches Go)
        url = url.replacingOccurrences(of: "\n", with: "%0A")
        url = url.replacingOccurrences(of: "\t", with: "%09")

        // Short-circuit data URIs — resolve against a base would corrupt them
        if url.lowercased().hasPrefix("data:") {
            return percentEncodeURL(url)
        }

        // Preserve query parameter order while normalizing encoding (matches Go's ParseAndEncodeQuery)
        if let queryStart = url.range(of: "?") {
            let base = String(url[url.startIndex..<queryStart.lowerBound])
            let rest = String(url[queryStart.upperBound...])
            // Split rest into query and fragment
            let (rawQuery, fragment) = splitQueryFragment(rest)
            let encodedQuery = parseAndEncodeQuery(rawQuery)
            let plusFixed = encodedQuery.replacingOccurrences(of: "+", with: "%20")
            url = base + "?" + plusFixed + (fragment.isEmpty ? "" : "#" + fragment)
        }

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

        return percentEncodeURL(url)
    }

    /// Percent-encode the characters Go's percentEncodingReplacer handles.
    private func percentEncodeURL(_ url: String) -> String {
        return url
            .replacingOccurrences(of: " ", with: "%20")
            .replacingOccurrences(of: "[", with: "%5B")
            .replacingOccurrences(of: "]", with: "%5D")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: "<", with: "%3C")
            .replacingOccurrences(of: ">", with: "%3E")
    }

    /// Split "query&params#fragment" into ("query&params", "fragment").
    private func splitQueryFragment(_ s: String) -> (String, String) {
        if let hashIdx = s.firstIndex(of: "#") {
            return (String(s[s.startIndex..<hashIdx]), String(s[s.index(after: hashIdx)...]))
        }
        return (s, "")
    }

    /// Preserve query parameter order while normalizing percent-encoding.
    /// Mirrors Go's ParseAndEncodeQuery: split on "&", decode+re-encode each key/value.
    func parseAndEncodeQuery(_ rawQuery: String) -> String {
        guard !rawQuery.isEmpty else { return "" }
        let parts = rawQuery.split(separator: "&", omittingEmptySubsequences: false)
        return parts.map { part -> String in
            let s = String(part)
            if let eqIdx = s.firstIndex(of: "=") {
                let key = decodeAndEncode(String(s[s.startIndex..<eqIdx]))
                let val = String(s[s.index(after: eqIdx)...])
                return val.isEmpty ? key + "=" : key + "=" + decodeAndEncode(val)
            }
            return decodeAndEncode(s)
        }.joined(separator: "&")
    }

    private func decodeAndEncode(_ s: String) -> String {
        guard let decoded = s.removingPercentEncoding else { return s }
        // Re-encode using percent encoding (space → %20, not +)
        return decoded.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
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
