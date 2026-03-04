import Foundation
import SwiftSoup

let refLinksKey = "reference_links"

struct RefLink {
    let url: String
    let title: String
}

public class ReferenceLinkPlugin: Plugin {
    public var name: String { return "reference-links" }
    let inlineLinks: Bool

    public init(inlineLinks: Bool = false) {
        self.inlineLinks = inlineLinks
    }

    public func initialize(conv: Converter) throws {
        if inlineLinks { return }
        registerLinkRenderer(conv: conv)
        registerImageRenderer(conv: conv)
        registerPostRenderer(conv: conv)
    }

    func registerPostRenderer(conv: Converter) {
        conv.Register.postRenderer({ ctx, result in
            let links: [RefLink]? = ctx.getState(refLinksKey)
            guard let items = links, !items.isEmpty else { return result }

            var output = result + "\n"
            for (i, link) in items.enumerated() {
                let num = i + 1
                if link.title.isEmpty {
                    output += "\n[\(num)]: \(link.url)"
                } else {
                    let t = link.title.replacingOccurrences(of: "\\", with: "\\\\")
                    let quotedTitle: String
                    let hasDouble = t.contains("\"")
                    let hasSingle = t.contains("'")
                    if hasDouble && hasSingle {
                        quotedTitle = "\"" + t.replacingOccurrences(of: "\"", with: "\\\"") + "\""
                    } else if hasDouble {
                        quotedTitle = "'\(t)'"
                    } else {
                        quotedTitle = "\"\(t)\""
                    }
                    output += "\n[\(num)]: \(link.url) \(quotedTitle)"
                }
            }
            return output
        }, priority: 1055)
    }
}
