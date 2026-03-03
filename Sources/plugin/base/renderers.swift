import Foundation
import SwiftSoup

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
