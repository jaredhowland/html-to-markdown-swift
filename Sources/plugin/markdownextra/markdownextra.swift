import Foundation
import SwiftSoup

public class MarkdownExtraPlugin: Plugin {
    public var name: String { return "markdownextra" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        registerDefinitionLists(conv: conv)
        registerFootnotes(conv: conv)
        registerHeaderIds(conv: conv)
    }
}
