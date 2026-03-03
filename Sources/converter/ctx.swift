import Foundation
import SwiftSoup

public class Context {
    public let conv: Converter
    public var domain: String
    private var values: [String: Any] = [:]
    public var globalState: [String: Any] = [:]

    init(conv: Converter, domain: String) {
        self.conv = conv
        self.domain = domain
    }

    private init(copying other: Context) {
        self.conv = other.conv
        self.domain = other.domain
        self.values = other.values
        self.globalState = other.globalState
    }

    public func renderNodes(_ w: StringWriter, _ nodes: [Node]) {
        conv.handleRenderNodes(ctx: self, w: w, nodes: nodes)
    }
    public func renderChildNodes(_ w: StringWriter, _ n: Node) {
        renderNodes(w, n.getChildNodes())
    }

    public func escapeContent(_ content: String) -> String {
        return conv.escapeContent(content)
    }
    public func unEscapeContent(_ content: String) -> String {
        return conv.unEscapeContent(content)
    }

    public func withValue(_ key: String, _ val: Any) -> Context {
        let copy = Context(copying: self)
        copy.values[key] = val
        return copy
    }
    public func getValue<V>(_ key: String) -> V? {
        return values[key] as? V
    }

    public func getState<V>(_ key: String) -> V? { return globalState[key] as? V }
    public func setState<V>(_ key: String, val: V) { globalState[key] = val }
    public func updateState<V>(_ key: String, fn: (V?) -> V) {
        let current = globalState[key] as? V
        globalState[key] = fn(current)
    }

    // MARK: - URL assembly
    /// Mirrors Go's ctx.AssembleAbsoluteURL.
    public func assembleAbsoluteURL(tagName: String, rawURL: String) -> String {
        return defaultAssembleAbsoluteURL(rawURL, domain: domain.isEmpty ? nil : domain)
    }
}
