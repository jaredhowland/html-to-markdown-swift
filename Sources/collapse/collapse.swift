import Foundation
import SwiftSoup

/// Set of HTML block-level element tag names (matches Go's NameIsBlockNode)
/// Note: table sub-elements (tr, td, th, thead, tbody, tfoot) are NOT included,
/// matching Go's dom.NameIsBlockNode which returns false for these elements.
let htmlBlockTags: Set<String> = [
    "address", "article", "aside", "blockquote", "canvas", "dd", "div",
    "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
    "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li", "main",
    "nav", "noscript", "ol", "p", "pre", "section", "table", "ul", "video",
    "body", "html", "head",
]

/// Collapse whitespace in HTML document following Go's collapse.Collapse algorithm exactly.
/// Mirrors the Go library's DFS traversal that visits elements on both entry and exit.
func collapseHTMLWhitespace(_ document: Document) throws {
    var prevText: TextNode? = nil
    var keepLeadingWs = false
    try collapseChildren(document, prevText: &prevText, keepLeadingWs: &keepLeadingWs)
    try trimTrailingSpace(&prevText)
}

/// Recursively collapse children of an element, updating shared state.
/// Mirrors Go's collapse.Collapse traversal where elements are visited on entry AND exit.
private func collapseChildren(
    _ parent: Node,
    prevText: inout TextNode?,
    keepLeadingWs: inout Bool
) throws {
    for child in parent.getChildNodes() {
        if let textNode = child as? TextNode {
            var text = replaceAnyWhitespaceWithSpace(textNode.getWholeText())

            // Trim leading space if prev text ended with space (or no prev text)
            if !keepLeadingWs && !text.isEmpty && text.first == " " {
                if prevText == nil || prevText?.getWholeText().last == " " {
                    text = String(text.dropFirst())
                }
            }

            if text.isEmpty {
                try textNode.remove()
                continue
            }

            try textNode.text(text)
            prevText = textNode
            keepLeadingWs = false

        } else if let element = child as? Element {
            let hasChildren = !element.getChildNodes().isEmpty
            let shouldRecurse = hasChildren && !isPreformatted(element)

            // ENTRY: apply element whitespace rules
            applyElementWhitespaceRules(element, prevText: &prevText, keepLeadingWs: &keepLeadingWs)

            if shouldRecurse {
                try collapseChildren(element, prevText: &prevText, keepLeadingWs: &keepLeadingWs)

                // EXIT: apply same rules again (mirrors Go's second visit when returning from children)
                applyElementWhitespaceRules(element, prevText: &prevText, keepLeadingWs: &keepLeadingWs)
            }
            // Comment, DocType, etc.: skip (Go ignores them for whitespace purposes)
        }
    }
}

/// Apply whitespace state rules for an element (used on both entry and exit).
/// Mirrors Go's element branch in collapse.Collapse.
private func applyElementWhitespaceRules(
    _ element: Element,
    prevText: inout TextNode?,
    keepLeadingWs: inout Bool
) {
    let tagName = element.tagName().lowercased()
    if htmlBlockTags.contains(tagName) || tagName == "br" {
        // Block elements and <br>: trim trailing space from previous text, reset
        if let pt = prevText {
            var ptText = pt.getWholeText()
            if ptText.last == " " {
                ptText = String(ptText.dropLast())
                if ptText.isEmpty {
                    try? pt.remove()
                    prevText = nil
                } else {
                    try? pt.text(ptText)
                }
            }
        }
        prevText = nil
        keepLeadingWs = false
    } else if inlineVoidTags.contains(tagName) || isPreformatted(element) || tagName == "code" {
        // Void elements, preformatted inline, and <code>: protect leading space of next text
        prevText = nil
        keepLeadingWs = true
    } else if prevText != nil {
        // Other inline elements: drop protection if set
        keepLeadingWs = false
    }
}

private func trimTrailingSpace(_ prevText: inout TextNode?) throws {
    guard let pt = prevText else { return }
    var ptText = pt.getWholeText()
    if ptText.last == " " {
        ptText = String(ptText.dropLast())
        if ptText.isEmpty {
            try pt.remove()
        } else {
            try pt.text(ptText)
        }
    }
    prevText = nil
}
