import Foundation
import SwiftSoup

extension Converter {
    /// Convert an HTML string to Markdown
    func convertString(_ html: String) throws -> String {
        let (processedHTML, commentPairs) = extractHTMLComments(html)
        let document = try SwiftSoup.parse(processedHTML)

        // Pre-render: document-level plugin transformations (runs BEFORE collapse, matching Go's order)
        for plugin in plugins {
            try plugin.handleDocumentPreRender(document: document, converter: self)
        }

        // Pre-render: collapse HTML whitespace (runs AFTER plugin pre-render, matching Go's PriorityLate)
        try collapseHTMLWhitespace(document)

        var result = try convertNode(document)

        // Post-render: trim document-level whitespace (matches Go's postRenderTrimContent)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = trimConsecutiveNewlines(result)
        result = trimUnnecessaryHardLineBreaks(result)

        if getOptions().escapeMode != .disabled {
            result = applySmartEscaping(result)
        }

        // Restore code block newline markers after all post-processing
        result = result.replacingOccurrences(of: String(codeBlockNewlineMarker), with: "\n")

        // Restore original HTML comments that SwiftSoup may not round-trip faithfully.
        // Apply the same HTML entity escaping that Go's html.Render uses for comment data.
        for (placeholder, original) in commentPairs {
            result = result.replacingOccurrences(of: placeholder, with: htmlEscapeComment(original))
        }

        return result
    }

    /// Replace every HTML comment in `html` with a unique placeholder so that SwiftSoup
    /// never has a chance to lose data (e.g. extra leading dashes in `<!------...`).
    /// Returns the substituted HTML and a list of (placeholder, original) pairs used
    /// to restore the originals in the output markdown.
    func extractHTMLComments(_ html: String) -> (String, [(String, String)]) {
        guard let regex = try? NSRegularExpression(pattern: #"<!--[\s\S]*?-->"#) else {
            return (html, [])
        }

        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        guard !matches.isEmpty else { return (html, []) }

        var pairs: [(String, String)] = []
        var resultParts: [String] = []
        var lastEnd = html.startIndex

        for (counter, match) in matches.enumerated() {
            guard let range = Range(match.range, in: html) else { continue }
            resultParts.append(String(html[lastEnd..<range.lowerBound]))
            let original = String(html[range])
            let placeholder = "<!--__SWIFTMC\(counter)__-->"
            pairs.append((placeholder, original))
            resultParts.append(placeholder)
            lastEnd = range.upperBound
        }
        resultParts.append(String(html[lastEnd...]))

        return (resultParts.joined(), pairs)
    }

    /// Apply HTML entity escaping to comment content, matching Go's html.Render behaviour
    /// for CommentNode (which calls escape() on the data).
    func htmlEscapeComment(_ comment: String) -> String {
        guard comment.hasPrefix("<!--"), comment.hasSuffix("-->") else { return comment }
        let data = String(comment.dropFirst(4).dropLast(3))
        let escaped = data
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<!--\(escaped)-->"
    }

    /// Convert an HTML document node to Markdown
    func convertNode(_ node: Node) throws -> String {
        if let textNode = node as? TextNode {
            return try processTextNode(textNode)
        }

        var result = ""
        var wasRendered = false

        // Run pre-render handlers
        for plugin in plugins {
            try plugin.handlePreRender(node: node, converter: self)
        }

        // Render the node
        for plugin in plugins {
            if let rendered = try plugin.handleRender(node: node, converter: self) {
                result = rendered
                wasRendered = true
                break
            }
        }

        // Fallback: if nothing rendered, render children by default
        if !wasRendered {
            var combined = ""
            for child in node.getChildNodes() {
                combined += try convertNode(child)
            }
            result = combined
        }

        // Run post-render handlers
        for plugin in plugins {
            result = try plugin.handlePostRender(node: node, content: result, converter: self)
        }

        return result
    }

    /// Process a text node
    func processTextNode(_ node: TextNode) throws -> String {
        var text = node.getWholeText()

        // Run text transform handlers
        for plugin in plugins {
            text = try plugin.handleTextTransform(text: text, converter: self)
        }

        return text
    }
}
