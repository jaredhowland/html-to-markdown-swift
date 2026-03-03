import Foundation
import SwiftSoup

/// Set of HTML block-level element tag names
let htmlBlockTags: Set<String> = [
    "address", "article", "aside", "blockquote", "canvas", "dd", "div",
    "dl", "dt", "fieldset", "figcaption", "figure", "footer", "form",
    "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li", "main",
    "nav", "noscript", "ol", "p", "pre", "section", "table", "tfoot",
    "thead", "tbody", "tr", "th", "td", "ul", "video",
    "body", "html", "head",
]

/// Collapse whitespace in HTML document following browser whitespace rules.
/// Text nodes in inline context have runs of whitespace collapsed to single space.
/// Whitespace-only text nodes adjacent to block elements are removed.
func collapseHTMLWhitespace(_ document: Document) throws {
    try processNode(document)
}

private func processNode(_ node: Node) throws {
    if let textNode = node as? TextNode {
        let raw = textNode.getWholeText()
        // Collapse runs of whitespace to single space
        let collapsed = collapseWhitespaceRun(raw)
        if collapsed != raw {
            try textNode.text(collapsed)
        }
        return
    }

    guard let element = node as? Element else {
        // Recurse for other node types
        for child in node.getChildNodes() {
            try processNode(child)
        }
        return
    }

    // For pre/code elements, don't collapse whitespace (preserve formatting)
    let tagName = element.tagName().lowercased()
    if tagName == "pre" || tagName == "code" || tagName == "script" || tagName == "style" {
        return
    }

    // Recurse into children first
    for child in element.getChildNodes() {
        try processNode(child)
    }

    // After processing children, remove whitespace-only text nodes
    // that are adjacent to block-level siblings.
    if htmlBlockTags.contains(tagName) {
        let children = element.getChildNodes()
        for child in children {
            guard let textNode = child as? TextNode else { continue }
            let text = textNode.getWholeText()
            guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            // Remove if at least one adjacent visible sibling is a block-level element (or boundary)
            let prevIsBlock = isBlockNode(prevVisibleSibling(textNode))
            let nextIsBlock = isBlockNode(nextVisibleSibling(textNode))
            if prevIsBlock || nextIsBlock {
                try textNode.remove()
            }
        }
    }
}

/// Returns the previous visible (non-comment) sibling node
private func prevVisibleSibling(_ node: Node) -> Node? {
    var sibling = node.previousSibling()
    while let s = sibling {
        if s is Comment {
            sibling = s.previousSibling()
        } else {
            return s
        }
    }
    return nil
}

/// Returns the next visible (non-comment) sibling node
private func nextVisibleSibling(_ node: Node) -> Node? {
    var sibling = node.nextSibling()
    while let s = sibling {
        if s is Comment {
            sibling = s.nextSibling()
        } else {
            return s
        }
    }
    return nil
}

/// Returns true if node is a block-level element or absent (nil = boundary)
private func isBlockNode(_ node: Node?) -> Bool {
    guard let node = node else { return true }
    if let element = node as? Element {
        return htmlBlockTags.contains(element.tagName().lowercased())
    }
    return false
}

/// Collapse consecutive whitespace characters (space, tab, newline, CR) to a single space
private func collapseWhitespaceRun(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    var prevWasSpace = false
    for ch in text {
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            if !prevWasSpace {
                result.append(" ")
                prevWasSpace = true
            }
        } else {
            result.append(ch)
            prevWasSpace = false
        }
    }
    return result
}
