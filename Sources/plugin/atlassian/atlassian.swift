import Foundation
import SwiftSoup

public class AtlassianPlugin: Plugin {
    public var name: String { return "atlassian" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        registerAutolinks(conv: conv)
        registerImageSizing(conv: conv)
        registerCodeBlocks(conv: conv)
        registerAttachments(conv: conv)
    }
}
