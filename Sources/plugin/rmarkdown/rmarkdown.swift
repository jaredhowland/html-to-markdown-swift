import Foundation
import SwiftSoup

public class RMarkdownPlugin: Plugin {
    public var name: String { return "rmarkdown" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(PandocPlugin())
        registerTabsets(conv: conv)
        registerFigureCaptions(conv: conv)
    }
}
