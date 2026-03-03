import Foundation
import SwiftSoup

/// Configuration for HTML to Markdown conversion
public enum ConverterOption {
    /// Base URL for resolving relative links
    case domain(String)
    /// CSS selectors to exclude from conversion
    case excludeSelectors([String])
    /// CSS selectors to include in conversion (excludes everything else)
    case includeSelector(String)
    /// Escape mode for special characters
    case escapeMode(EscapeMode)
    /// Custom tag type configuration
    case tagTypeConfiguration((inout TagTypeRegistry) -> Void)
    /// Custom renderers
    case customRenderers([(tagName: String, renderer: NodeRenderer)])
}

/// Escape modes for special characters in Markdown
public enum EscapeMode {
    case smart  // Default: escape only when necessary
    case disabled  // Don't escape special characters
}

/// The main converter class that transforms HTML to Markdown
public class Converter {
    private var plugins: [Plugin] = []
    private var converterOptions: ConversionOptions = ConversionOptions()
    private var registry: TagTypeRegistry = TagTypeRegistry()
    private var renderers: [String: NodeRenderer] = [:]
    private let lock = NSLock()
    
    /// Initialize a converter with plugins and options
    init(plugins: [Plugin] = [], options: [ConverterOption] = []) {
        self.plugins = plugins

        // Register plugins first, then process options so that custom renderers
        // from options can override plugin defaults.
        for plugin in plugins {
            plugin.register(with: self)
        }

        processOptions(options)
    }
    
    /// Convert an HTML string to Markdown
    func convertString(_ html: String) throws -> String {
        let document = try SwiftSoup.parse(html)

        // Pre-render: document-level plugin transformations (runs BEFORE collapse, matching Go's order)
        for plugin in plugins {
            try plugin.handleDocumentPreRender(document: document, converter: self)
        }

        // Pre-render: collapse HTML whitespace (runs AFTER plugin pre-render, matching Go's PriorityLate)
        try collapseHTMLWhitespace(document)

        var result = try convertNode(document)

        // Post-render: trim document-level whitespace (matches Go's postRenderTrimContent)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        result = trimConsecutiveNewlines(result)
        result = trimUnnecessaryHardLineBreaks(result)

        if getOptions().escapeMode != .disabled {
            result = applySmartEscaping(result)
        }

        // Restore code block newline markers after all post-processing
        result = result.replacingOccurrences(of: String(codeBlockNewlineMarker), with: "\n")

        return result
    }
    
    /// Convert an HTML document node to Markdown
    func convertNode(_ node: Node) throws -> String {
        if let textNode = node as? TextNode {
            return try processTextNode(textNode)
        }

        var result = ""
        var wasRendered = false

        // Run pre-render handlers
        for plugin in plugins {
            try plugin.handlePreRender(node: node, converter: self)
        }

        // Render the node
        for plugin in plugins {
            if let rendered = try plugin.handleRender(node: node, converter: self) {
                result = rendered
                wasRendered = true
                break
            }
        }

        // Fallback: if nothing rendered, render children by default
        if !wasRendered {
            var combined = ""
            for child in node.getChildNodes() {
                combined += try convertNode(child)
            }
            result = combined
        }

        // Run post-render handlers
        for plugin in plugins {
            result = try plugin.handlePostRender(node: node, content: result, converter: self)
        }

        return result
    }
    
    /// Process a text node
    private func processTextNode(_ node: TextNode) throws -> String {
        var text = node.getWholeText()
        
        // Run text transform handlers
        for plugin in plugins {
            text = try plugin.handleTextTransform(text: text, converter: self)
        }
        
        return text
    }
    
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
    
    /// Process converter options
    private func processOptions(_ options: [ConverterOption]) {
        for option in options {
            switch option {
            case .domain(let url):
                converterOptions.baseDomain = url
            case .excludeSelectors(let selectors):
                converterOptions.excludeSelectors = selectors
            case .includeSelector(let selector):
                converterOptions.includeSelector = selector
            case .escapeMode(let mode):
                converterOptions.escapeMode = mode
            case .tagTypeConfiguration(let config):
                config(&registry)
            case .customRenderers(let renderers):
                for (tag, renderer) in renderers {
                    registerRenderer(tag, renderer: renderer)
                }
            }
        }
    }
}

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
