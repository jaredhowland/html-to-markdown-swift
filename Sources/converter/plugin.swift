import Foundation
import SwiftSoup

/// Protocol for plugins that extend the conversion behavior
public protocol Plugin {
    /// The public name of the plugin, e.g. "base", "commonmark", "strikethrough", "table"
    var name: String { get }
    /// Initialize the plugin — registers handlers, validates config, etc. (mirrors Go's Init)
    func initialize(conv: Converter)
    /// Handle document-level pre-render phase (called once on the full document)
    func handleDocumentPreRender(document: Document, converter: Converter) throws
    /// Handle pre-render phase (before main rendering)
    func handlePreRender(node: Node, converter: Converter) throws
    /// Handle main render phase
    func handleRender(node: Node, converter: Converter) throws -> String?
    /// Handle post-render phase (after main rendering)
    func handlePostRender(node: Node, content: String, converter: Converter) throws -> String
    /// Handle text transformation
    func handleTextTransform(text: String, converter: Converter) throws -> String
}

/// Default implementation providing optional handlers
extension Plugin {
    public var name: String { return "" }
    public func handleDocumentPreRender(document: Document, converter: Converter) throws {}
    public func handlePreRender(node: Node, converter: Converter) throws {}
    public func handleRender(node: Node, converter: Converter) throws -> String? { return nil }
    public func handlePostRender(node: Node, content: String, converter: Converter) throws -> String { return content }
    public func handleTextTransform(text: String, converter: Converter) throws -> String { return text }
}
