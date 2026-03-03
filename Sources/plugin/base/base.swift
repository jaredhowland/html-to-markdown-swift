import Foundation
import SwiftSoup

/// Base plugin that provides fundamental HTML to Markdown conversion
class BasePlugin: Plugin {
    var name: String { return "base" }

    func initialize(conv converter: Converter) {
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
