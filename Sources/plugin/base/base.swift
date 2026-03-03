import Foundation
import SwiftSoup

public class BasePlugin: Plugin {
    public init() {}
    public var name: String { return "base" }

    public func initialize(conv: Converter) throws {
        for tag in ["head", "script", "style", "link", "meta",
                    "iframe", "noscript", "input", "textarea"] {
            conv.Register.tagType(tag, .remove, priority: PriorityStandard)
        }

        // Pre-render: remove .remove-tagged nodes from DOM (early)
        conv.Register.preRenderer({ ctx, doc in
            removeTaggedNodes(doc: doc, conv: ctx.conv)
        }, priority: PriorityEarly)

        // Pre-render: collapse HTML whitespace (late — after plugin DOM transforms)
        conv.Register.preRenderer({ ctx, doc in
            try? collapseHTMLWhitespace(doc) { name in
                ctx.conv.getTagType(name) == .block
            }
        }, priority: PriorityLate)

        // Text transformer: escape < > and mark escape candidates
        conv.Register.textTransformer({ ctx, content in
            var result = content
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            if ctx.conv.escapeMode != .disabled {
                result = markEscapeCandidates(result, chars: ctx.conv.markdownChars)
            }
            return result
        }, priority: PriorityStandard)

        // Post-render: trim and clean up
        conv.Register.postRenderer({ ctx, result in
            var out = result.trimmingCharacters(in: .whitespacesAndNewlines)
            out = trimConsecutiveNewlines(out)
            out = trimUnnecessaryHardLineBreaks(out)
            return out
        }, priority: PriorityStandard)

        // Post-render: unescape (runs after trim)
        conv.Register.postRenderer({ ctx, result in
            return ctx.unEscapeContent(result)
        }, priority: PriorityStandard + 20)

        // Render: catch-all fallback (very late priority)
        conv.Register.renderer({ ctx, w, n in
            let tagName = n.nodeName().lowercased()
            let type = ctx.conv.getTagType(tagName)
            if type == .remove { return .success }
            if type == .block { w.writeString("\n\n") }
            ctx.renderChildNodes(w, n)
            if type == .block { w.writeString("\n\n") }
            return .success
        }, priority: PriorityLate + 100)
    }
}

private func removeTaggedNodes(doc: Document, conv: Converter) {
    func remove(_ node: Node) {
        let children = node.getChildNodes()
        let toRemove = children.filter { child in
            conv.getTagType(child.nodeName().lowercased()) == .remove
        }
        for n in toRemove { try? n.remove() }
        for child in node.getChildNodes() { remove(child) }
    }
    remove(doc)
}
