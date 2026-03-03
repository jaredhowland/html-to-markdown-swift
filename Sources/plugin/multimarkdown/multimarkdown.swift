import Foundation
import SwiftSoup

let mmdFootnotesKey = "mmd_footnotes"

struct MMDFootnote {
    let id: String
    let text: String
}

public class MultiMarkdownPlugin: Plugin {
    public var name: String { return "multimarkdown" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        registerSubSup(conv: conv)
        registerDefinitionLists(conv: conv)
        registerImageAttributes(conv: conv)
        registerFigure(conv: conv)
        registerFootnotes(conv: conv)
    }
}
