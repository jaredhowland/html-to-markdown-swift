import Foundation
import SwiftSoup

extension Converter {

    public func convertString(_ html: String) throws -> String {
        if let err = initError { throw err }

        guard !getRenderHandlers().isEmpty else {
            throw ConversionError.conversionFailed(
                #"no render handlers are registered. did you forget to register the "commonmark" and "base" plugins?"#
            )
        }

        let ctx = Context(conv: self, domain: domain)
        let (processedHTML, commentPairs) = extractHTMLComments(html)
        let document = try SwiftSoup.parse(processedHTML)

        try applySelectors(document)

        for handler in getPreRenderHandlers() { handler(ctx, document) }

        let w = StringWriter()
        handleRenderNode(ctx: ctx, w: w, node: document)
        var result = w.string

        for handler in getPostRenderHandlers() { result = handler(ctx, result) }

        result = result.replacingOccurrences(of: String(codeBlockNewlineMarker), with: "\n")

        for (placeholder, original) in commentPairs {
            result = result.replacingOccurrences(of: placeholder, with: htmlEscapeComment(original))
        }

        return result
    }

    private func applySelectors(_ document: Document) throws {
        if !excludeSelectors.isEmpty {
            for selector in excludeSelectors {
                let elements = try document.select(selector)
                for el in elements { try el.remove() }
            }
        }
        if let selector = includeSelector {
            let included = try document.select(selector)
            let includedHTML = included.map { $0.description }.joined()
            let body = document.body()
            try body?.html(includedHTML)
        }
    }

    func extractHTMLComments(_ html: String) -> (String, [(String, String)]) {
        guard let regex = try? NSRegularExpression(pattern: #"<!--[\s\S]*?-->"#) else { return (html, []) }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        guard !matches.isEmpty else { return (html, []) }
        var pairs: [(String, String)] = []
        var parts: [String] = []
        var lastEnd = html.startIndex
        for (counter, match) in matches.enumerated() {
            guard let range = Range(match.range, in: html) else { continue }
            parts.append(String(html[lastEnd..<range.lowerBound]))
            let original = String(html[range])
            let placeholder = "<!--__SWIFTMC\(counter)__-->"
            pairs.append((placeholder, original))
            parts.append(placeholder)
            lastEnd = range.upperBound
        }
        parts.append(String(html[lastEnd...]))
        return (parts.joined(), pairs)
    }

    func htmlEscapeComment(_ comment: String) -> String {
        guard comment.hasPrefix("<!--"), comment.hasSuffix("-->") else { return comment }
        let data = String(comment.dropFirst(4).dropLast(3))
        let escaped = data
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<!--\(escaped)-->"
    }
}
