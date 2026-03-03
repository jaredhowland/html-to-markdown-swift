import Foundation
import SwiftSoup

public class GFMPlugin: Plugin {
    public var name: String { return "gfm" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        try conv.Register.plugin(TaskListItemsPlugin())
        registerDefinitionLists(conv: conv)
        registerDetailsSummary(conv: conv)
        registerSubSup(conv: conv)
        registerAbbr(conv: conv)
    }
}
