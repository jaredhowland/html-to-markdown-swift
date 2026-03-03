import Foundation
import SwiftSoup

let pandocFootnotesKey = "pandoc_footnotes"

struct PandocFootnote {
    let id: String
    let text: String
}

public class PandocPlugin: Plugin {
    public var name: String { return "pandoc" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        try conv.Register.plugin(TaskListItemsPlugin())
        registerDefinitionLists(conv: conv)
        registerFootnotes(conv: conv)
        registerSubSup(conv: conv)
        registerHeaderIds(conv: conv)
        registerMath(conv: conv)
    }
}
