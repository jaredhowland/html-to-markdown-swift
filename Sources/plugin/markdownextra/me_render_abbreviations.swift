import Foundation
import SwiftSoup

let meAbbreviationsKey = "me_abbreviations"

struct MEAbbreviation: Equatable {
    let abbr: String
    let title: String
}

extension MarkdownExtraPlugin {
    func registerAbbreviations(conv: Converter) {
        // Inline renderer: render text, collect (abbr, title) pair into ctx state
        conv.Register.rendererFor("abbr", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            let text = buf.string
            w.writeString(text)

            if let elem = n as? Element,
               let title = try? elem.attr("title"),
               !title.isEmpty {
                var existing: [MEAbbreviation] = ctx.getState(meAbbreviationsKey) ?? []
                let entry = MEAbbreviation(abbr: text, title: title)
                if !existing.contains(entry) {
                    existing.append(entry)
                    ctx.setState(meAbbreviationsKey, val: existing)
                }
            }
            return .success
        }, priority: PriorityEarly)

        // Post-renderer: append *[Abbr]: Full Text lines
        conv.Register.postRenderer({ ctx, result in
            let abbrevs: [MEAbbreviation]? = ctx.getState(meAbbreviationsKey)
            guard let items = abbrevs, !items.isEmpty else { return result }
            var output = result + "\n"
            for item in items {
                output += "\n*[\(item.abbr)]: \(item.title)"
            }
            return output
        }, priority: 1060)
    }
}
