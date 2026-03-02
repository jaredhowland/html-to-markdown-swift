import Foundation
import SwiftSoup

/// Protocol for plugins that extend the conversion behavior
public protocol Plugin {
    /// Register the plugin with the converter
    func register(with converter: Converter)
    /// Handle pre-render phase (before main rendering)
    func handlePreRender(node: Node, converter: Converter) throws

    /// Handle main render phase
    func handleRender(node: Node, converter: Converter) throws -> String?

    /// Handle post-render phase (after main rendering)
    func handlePostRender(node: Node, content: String, converter: Converter) throws -> String

    /// Handle text transformation
    func handleTextTransform(text: String, converter: Converter) throws -> String

    /// Handle unescaping of special characters
    func handleUnEscape(text: String, converter: Converter) throws -> String
}

/// Default implementation providing optional handlers
extension Plugin {
    public func handlePreRender(node: Node, converter: Converter) throws {}
    public func handleRender(node: Node, converter: Converter) throws -> String? { return nil }
    public func handlePostRender(node: Node, content: String, converter: Converter) throws -> String { return content }
    public func handleTextTransform(text: String, converter: Converter) throws -> String { return text }
    public func handleUnEscape(text: String, converter: Converter) throws -> String { return text }
}

/// Helper function to get element name
func getElementName(_ node: Node) -> String? {
    if let element = node as? Element {
        return element.tagName()
    }
    return nil
}

/// Helper function to get children
func getChildren(_ node: Node) -> [Node] {
    if let element = node as? Element {
        var children: [Node] = []
        for child in element.getChildNodes() {
            children.append(child)
        }
        return children
    }
    return []
}

/// Helper function to render children
func renderChildren(_ node: Node, converter: Converter) throws -> String {
    var result = ""
    for child in getChildren(node) {
        result += try converter.convertNode(child)
    }
    return result
}

/// Helper to get attribute value
func getAttribute(_ node: Node, _ name: String) -> String? {
    if let element = node as? Element {
        return try? element.attr(name)
    }
    return nil
}

/// Helper to get all attributes
func getAttributes(_ node: Node) -> [String: String] {
    if let element = node as? Element {
        var attrs: [String: String] = [:]
        if let attributes = try? element.getAttributes() {
            for attr in attributes.asList() {
                attrs[attr.getKey()] = attr.getValue()
            }
        }
        return attrs
    }
    return [:]
}

/// Helper to check if element has class
func hasClass(_ node: Node, _ className: String) -> Bool {
    if let element = node as? Element {
        return (try? element.hasClass(className)) ?? false
    }
    return false
}

/// Helper to get text content
func getTextContent(_ node: Node) -> String {
    if let textNode = node as? TextNode {
        return textNode.text()
    }
    if let element = node as? Element {
        return (try? element.text()) ?? ""
    }
    return ""
}

