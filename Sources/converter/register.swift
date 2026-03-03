import Foundation
import SwiftSoup

/// Matches Go's dom.NameIsBlockNode — used by converter getType(for:) fallback.
private let domBlockTags: Set<String> = [
    "address", "article", "aside", "blockquote", "details", "dialog",
    "dd", "div", "dl", "dt", "fieldset", "figcaption", "figure",
    "footer", "form",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "header", "hgroup", "hr", "li", "main", "nav",
    "ol", "p", "pre", "section", "table", "ul",
]

/// Matches Go's dom.NameIsInlineNode — used by converter getType(for:) fallback.
private let domInlineTags: Set<String> = [
    "#text", "a", "abbr", "acronym", "audio",
    "b", "bdi", "bdo", "big", "br", "button",
    "canvas", "cite", "code", "data", "datalist",
    "del", "dfn", "em", "embed",
    "i", "iframe", "img", "input", "ins",
    "kbd", "label", "map", "mark", "meter",
    "noscript", "object", "output", "picture", "progress",
    "q", "ruby", "s", "samp", "script", "select",
    "slot", "small", "span", "strong", "sub", "sup",
    "svg", "template", "textarea", "time",
    "u", "tt", "var", "video", "wbr",
]

/// Type alias for node rendering function
public typealias NodeRenderer = (Node, Converter) throws -> String?

/// Tag types for HTML elements
public enum TagType {
    case block
    case inline
    case remove
}

/// Handler priority for plugin operations
public enum HandlerPriority {
    case early
    case standard
    case late
}

/// Conversion options
struct ConversionOptions {
    var baseDomain: String?
    var excludeSelectors: [String] = []
    var includeSelector: String?
    var escapeMode: EscapeMode = .smart
}

/// Registry for tag type mappings
public class TagTypeRegistry {
    private var types: [String: (type: TagType, priority: HandlerPriority)] = [:]

    public init() {}

    public func register(tagName: String, type: TagType, priority: HandlerPriority) {
        types[tagName] = (type, priority)
    }

    public func getType(for tagName: String) -> TagType {
        if let entry = types[tagName] {
            return entry.type
        }
        // Fallback mirrors Go's dom.NameIsBlockNode / dom.NameIsInlineNode
        let lower = tagName.lowercased()
        if domBlockTags.contains(lower) { return .block }
        if domInlineTags.contains(lower) { return .inline }
        return .inline
    }
}

extension Converter {
    /// Register a custom tag renderer
    func registerRenderer(_ tagName: String, renderer: @escaping NodeRenderer) {
        lock.lock()
        defer { lock.unlock() }
        renderers[tagName.lowercased()] = renderer
    }

    /// Register a tag type
    func registerTagType(_ tagName: String, type: TagType, priority: HandlerPriority = .standard) {
        lock.lock()
        defer { lock.unlock() }
        registry.register(tagName: tagName.lowercased(), type: type, priority: priority)
    }

    /// Get the tag type for a given tag name
    func getTagType(_ tagName: String) -> TagType {
        lock.lock()
        defer { lock.unlock() }
        return registry.getType(for: tagName.lowercased())
    }

    /// Get a registered renderer
    func getRenderer(_ tagName: String) -> NodeRenderer? {
        lock.lock()
        defer { lock.unlock() }
        return renderers[tagName.lowercased()]
    }

    /// Get converter options
    func getOptions() -> ConversionOptions {
        return converterOptions
    }
}
