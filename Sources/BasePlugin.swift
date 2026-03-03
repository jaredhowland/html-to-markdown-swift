import Foundation
import SwiftSoup

/// Base plugin that provides fundamental HTML to Markdown conversion
class BasePlugin: Plugin {
    func register(with converter: Converter) {
        let blockTags = [
            "div", "p", "article", "section", "header", "footer", "main", "nav",
            "blockquote", "pre", "ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6",
            "table", "thead", "tbody", "tfoot", "tr", "td", "th", "hr", "figure", "figcaption"
        ]
        let inlineTags = [
            "span", "strong", "em", "b", "i", "u", "code", "a", "img", "br",
            "abbr", "cite", "del", "dfn", "ins", "kbd", "mark", "q", "s", "samp", "small",
            "sub", "sup", "var", "tt"
        ]
        let removeTags = ["style", "script", "meta", "link", "noscript", "head", "iframe", "input", "textarea"]

        for tag in blockTags {
            converter.registerTagType(tag, type: .block, priority: .early)
        }
        for tag in inlineTags {
            converter.registerTagType(tag, type: .inline, priority: .early)
        }
        for tag in removeTags {
            converter.registerTagType(tag, type: .remove, priority: .early)
        }

        registerDefaultRenderers(converter: converter)
    }

    func handlePreRender(node: Node, converter: Converter) throws {
        if let element = node as? Element {
            let tagName = element.tagName()
            if converter.getTagType(tagName) == .remove {
                try element.remove()
            }
        }
    }

    func handleRender(node: Node, converter: Converter) throws -> String? {
        guard let element = node as? Element else {
            if let textNode = node as? TextNode {
                return textNode.getWholeText()
            }
            return nil
        }

        let tagName = element.tagName()

        if let renderer = converter.getRenderer(tagName) {
            return try renderer(element, converter)
        }

        return try renderDefault(element: element, converter: converter)
    }

    func handleTextTransform(text: String, converter: Converter) throws -> String {
        var result = text
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if converter.getOptions().escapeMode != .disabled {
            result = markEscapeCandidates(result)
        }
        return result
    }

    private func renderDefault(element: Element, converter: Converter) throws -> String {
        let children = try renderChildren(element, converter: converter)
        let tagType = converter.getTagType(element.tagName())

        switch tagType {
        case .block:
            return trimConsecutiveNewlines("\n\n\(collapseInlineSpaces(children))\n\n")
        case .inline:
            return children
        case .remove:
            return ""
        }
    }

    private func registerDefaultRenderers(converter: Converter) {
        converter.registerRenderer("document") { node, converter in
            try renderChildren(node, converter: converter)
        }
        for tag in ["#document", "div", "section", "article", "main", "header", "footer", "p"] {
            converter.registerRenderer(tag) { node, converter in
                let children = try renderChildren(node, converter: converter)
                return trimConsecutiveNewlines("\n\n\(collapseInlineSpaces(children))\n\n")
            }
        }
    }
}

/// Trim 3+ consecutive newlines down to 2
func trimConsecutiveNewlines(_ text: String) -> String {
    let pattern = "\n{3,}"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\n\n")
    }
    return text
}

/// Collapse inline whitespace (multiple spaces/tabs to single space)
func collapseWhitespace(_ text: String) -> String {
    let pattern = "[ \\t]+"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ").trimmingCharacters(in: .whitespaces)
    }
    return text.trimmingCharacters(in: .whitespaces)
}

/// Collapse runs of 2+ consecutive spaces that are not part of a Markdown hard line break ("  \n").
/// Used in block element renderers to normalize spaces left behind by empty inline elements.
func collapseInlineSpaces(_ text: String) -> String {
    // Pattern: 2+ spaces not preceded by \n (to protect indentation) and not followed by \n (to protect "  \n" hard breaks)
    let pattern = "(?<!\\n)  +(?!\\n)"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
    }
    return text
}

// MARK: - Public renderer helpers (for plugin authors)

/// Render the node as raw HTML
public func RenderAsHTML(_ node: Node, _ converter: Converter) throws -> String? {
    guard let element = node as? Element else { return nil }
    return try element.outerHtml()
}

/// Render the node wrapper as HTML but children as markdown
public func RenderAsHTMLWrapper(_ node: Node, _ converter: Converter) throws -> String? {
    guard let element = node as? Element else { return nil }
    let name = element.tagName()
    let children = try renderChildren(node, converter: converter)
    return "<\(name)>\n\n\(children)\n\n</\(name)>"
}

/// Render children as markdown, ignoring the wrapper tag
public func RenderAsPlaintextWrapper(_ node: Node, _ converter: Converter) throws -> String? {
    return try renderChildren(node, converter: converter)
}
