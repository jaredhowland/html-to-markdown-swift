import Foundation
import SwiftSoup

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
        // Default types based on tag name
        switch tagName.lowercased() {
        case "div", "p", "article", "section", "header", "footer", "main", "nav",
             "blockquote", "pre", "ul", "ol", "li", "h1", "h2", "h3", "h4", "h5", "h6", "table", "tr", "td", "th":
            return .block
        default:
            return .inline
        }
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
