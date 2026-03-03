import Foundation
import SwiftSoup

let domBlockTags: Set<String> = [
    "address", "article", "aside", "blockquote", "details", "dialog",
    "dd", "div", "dl", "dt", "fieldset", "figcaption", "figure",
    "footer", "form",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "header", "hgroup", "hr", "li", "main", "nav",
    "ol", "p", "pre", "section", "table", "ul",
]

let domInlineTags: Set<String> = [
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

public enum TagType {
    case block
    case inline
    case remove
}

public enum HandlerPriority {
    case early
    case standard
    case late
}

struct ConversionOptions {
    var baseDomain: String?
    var excludeSelectors: [String] = []
    var includeSelector: String?
    var escapeMode: EscapeMode = .smart
}

public class TagTypeRegistry {
    var types: [String: (type: TagType, priority: HandlerPriority)] = [:]
    var typeMap: [String: (type: TagType, priority: HandlerPriority)] { return types }

    public init() {}

    public func register(tagName: String, type: TagType, priority: HandlerPriority) {
        types[tagName.lowercased()] = (type, priority)
    }

    public func getType(for tagName: String) -> TagType {
        if let entry = types[tagName.lowercased()] { return entry.type }
        let lower = tagName.lowercased()
        if domBlockTags.contains(lower) { return .block }
        if domInlineTags.contains(lower) { return .inline }
        return .inline
    }
}

public struct RegisterAPI {
    unowned let conv: Converter

    public func plugin(_ p: Plugin) throws {
        guard !p.name.isEmpty else { throw ConversionError.pluginError("plugin has no name") }
        conv.lock.lock(); conv.registeredPluginNames.append(p.name); conv.storedPlugins.append(p); conv.lock.unlock()
        try p.initialize(conv: conv)
    }

    public func preRenderer(_ fn: @escaping HandlePreRenderFunc, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.preRenderHandlers.appendPrioritized(fn, priority)
    }

    public func renderer(_ fn: @escaping HandleRenderFunc, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.renderHandlers.appendPrioritized(fn, priority)
    }

    public func rendererFor(_ tagName: String, _ tagType: TagType, _ fn: @escaping HandleRenderFunc, priority: Int) {
        self.tagType(tagName, tagType, priority: priority)
        let lower = tagName.lowercased()
        self.renderer({ ctx, w, n in
            let name = (n as? Element)?.tagName().lowercased() ?? n.nodeName().lowercased()
            guard name == lower else { return .tryNext }
            return fn(ctx, w, n)
        }, priority: priority)
    }

    public func postRenderer(_ fn: @escaping HandlePostRenderFunc, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.postRenderHandlers.appendPrioritized(fn, priority)
    }

    public func textTransformer(_ fn: @escaping HandleTextTransformFunc, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.textTransformHandlers.appendPrioritized(fn, priority)
    }

    public func escapedChar(_ chars: Character...) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        chars.forEach { conv.markdownChars.insert($0) }
    }

    public func unEscaper(_ fn: @escaping HandleUnEscapeFunc, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.unEscapeHandlers.appendPrioritized(fn, priority)
    }

    public func tagType(_ tagName: String, _ type: TagType, priority: Int) {
        conv.lock.lock(); defer { conv.lock.unlock() }
        conv.tagTypesMap[tagName.lowercased(), default: []].appendPrioritized(type, priority)
    }
}

// Legacy helpers
func getChildren(_ node: Node) -> [Node] { return node.getChildNodes() }
func renderChildren(_ node: Node, converter: Converter) throws -> String {
    let ctx = Context(conv: converter, domain: converter.domain)
    let w = StringWriter()
    converter.handleRenderNodes(ctx: ctx, w: w, nodes: node.getChildNodes())
    return w.string
}
