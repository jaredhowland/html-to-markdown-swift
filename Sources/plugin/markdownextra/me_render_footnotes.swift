import Foundation
import SwiftSoup

let meFootnotesKey = "me_footnotes"

struct MEFootnote {
    let id: String
    let text: String
}

extension MarkdownExtraPlugin {
    func registerFootnotes(conv: Converter) {
        conv.Register.preRenderer({ ctx, doc in
            var footnotes: [MEFootnote] = []

            // PHP Markdown Extra: <div class="footnotes">
            // Also Pandoc: <section class="footnotes">
            let containers = (try? doc.select("div.footnotes, section.footnotes")) ?? Elements()
            for container in containers {
                let items = (try? container.select("li[id^=fn]")) ?? Elements()
                for li in items {
                    let rawId = li.id()
                    let fnId = rawId
                        .replacingOccurrences(of: "fn:", with: "")
                        .replacingOccurrences(of: "fn", with: "")
                    if let reverseLinks = try? li.select("a.reversefootnote, a.footnote-back") {
                        for link in reverseLinks { try? link.remove() }
                    }
                    let text = (try? li.text()) ?? ""
                    if !text.isEmpty {
                        footnotes.append(MEFootnote(id: fnId, text: text))
                    }
                }
                try? container.remove()
            }

            if let body = doc.body(), let hrs = try? body.select("hr") {
                for hr in hrs.array().reversed() {
                    if (try? hr.nextElementSibling()) == nil {
                        try? hr.remove()
                    }
                    break
                }
            }

            if !footnotes.isEmpty {
                ctx.setState(meFootnotesKey, val: footnotes)
            }
        }, priority: 50)

        conv.Register.rendererFor("a", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard element.hasClass("footnote") || element.hasClass("footnote-ref") else { return .tryNext }
            let rawHref = (try? element.attr("href")) ?? ""
            let fnId = rawHref
                .replacingOccurrences(of: "#fn:", with: "")
                .replacingOccurrences(of: "#fn", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            w.writeString("[^\(fnId)]")
            return .success
        }, priority: PriorityEarly)

        conv.Register.postRenderer({ ctx, result in
            let footnotes: [MEFootnote]? = ctx.getState(meFootnotesKey)
            guard let fns = footnotes, !fns.isEmpty else { return result }
            var output = result
            for fn in fns {
                output += "\n\n[^\(fn.id)]: \(fn.text)"
            }
            return output
        }, priority: 1050)
    }
}
