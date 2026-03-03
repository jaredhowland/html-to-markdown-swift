import Foundation
import SwiftSoup

/// Tags that are preformatted (whitespace preserved inside them).
/// Matches Go's defaultIsPreformattedNode which returns true for "pre" and "code".
private let preformattedTags: Set<String> = ["pre", "code"]

/// Void (self-closing) HTML elements — matches Go's collapse.voidElements.
/// Used to protect surrounding whitespace during collapse (keepLeadingWs = true).
let inlineVoidTags: Set<String> = [
    "area", "base", "br", "col", "command", "embed", "hr",
    "img", "input", "keygen", "link", "meta", "param", "track", "wbr",
]

func isPreformatted(_ element: Element) -> Bool {
    return preformattedTags.contains(element.tagName().lowercased())
}

/// Returns true if node is a block-level element or absent (nil = boundary)
func isBlockNode(_ node: Node?) -> Bool {
    guard let node = node else { return true }
    if let element = node as? Element {
        return htmlBlockTags.contains(element.tagName().lowercased())
    }
    return false
}
