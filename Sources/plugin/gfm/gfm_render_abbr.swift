import Foundation
import SwiftSoup

extension GFMPlugin {
    func registerAbbr(conv: Converter) {
        conv.Register.rendererFor("abbr", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            let text = buf.string
            if let elem = n as? Element, elem.hasAttr("title"),
               let title = try? elem.attr("title"), !title.isEmpty {
                w.writeString("\(text) (\(title))")
            } else {
                w.writeString(text)
            }
            return .success
        }, priority: PriorityStandard)
    }
}
