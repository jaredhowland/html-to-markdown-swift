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
            // Handle non-Element nodes (e.g. Comment nodes) via registered renderers
            let nodeName = node.nodeName()
            if let renderer = converter.getRenderer(nodeName) {
                return try renderer(node, converter)
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
                let trimmed = children.trimmingCharacters(in: .init(charactersIn: " \t"))
                return trimConsecutiveNewlines("\n\n\(trimmed)\n\n")
            }
        }
    }
}

/// Trim consecutive newlines to at most 2, matching Go's TrimConsecutiveNewlines algorithm.
/// Spaces before a newline are consumed as part of that newline's sequence.
/// When a third or more newline is encountered, the excess newlines and their preceding spaces are dropped.
func trimConsecutiveNewlines(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    var spaceBuffer = ""
    var newlineCount = 0

    for ch in text {
        if ch == "\n" {
            newlineCount += 1
            if newlineCount <= 2 {
                result.append(contentsOf: spaceBuffer)
                result.append(ch)
            }
            spaceBuffer = ""
        } else if ch == " " {
            spaceBuffer.append(ch)
        } else {
            newlineCount = 0
            result.append(contentsOf: spaceBuffer)
            result.append(ch)
            spaceBuffer = ""
        }
    }
    result.append(contentsOf: spaceBuffer)
    return result
}

/// Remove hard line breaks ("  \n") immediately before empty lines, matching Go's TrimUnnecessaryHardLineBreaks.
func trimUnnecessaryHardLineBreaks(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "  \n\n", with: "\n\n")
    result = result.replacingOccurrences(of: "  \n  \n", with: "\n\n")
    result = result.replacingOccurrences(of: "  \n \n", with: "\n\n")
    return result
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
    guard let element = node as? Element else {
        if let comment = node as? Comment {
            return "\n\n<!--\(comment.getData())-->\n\n"
        }
        return nil
    }
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
