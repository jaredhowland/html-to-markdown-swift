import Foundation
import SwiftSoup

extension PandocPlugin {
    func registerFootnotes(conv: Converter) {
        conv.Register.preRenderer({ ctx, doc in
            var footnotes: [PandocFootnote] = []
            let containers = (try? doc.select("section.footnotes, div.footnotes")) ?? Elements()
            for container in containers {
                let items = (try? container.select("li[id^=fn]")) ?? Elements()
                for li in items {
                    let rawId = li.id()
                    // Pandoc uses "fn1", "fn2" etc (no colon); ME/PHP uses "fn:1"
                    let fnId = rawId
                        .replacingOccurrences(of: "fn:", with: "")
                        .replacingOccurrences(of: "fn", with: "")
                    if let backLinks = try? li.select("a.footnote-back, a.reversefootnote") {
                        for link in backLinks { try? link.remove() }
                    }
                    let text = (try? li.text()) ?? ""
                    if !text.isEmpty {
                        footnotes.append(PandocFootnote(id: fnId, text: text))
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
                ctx.setState(pandocFootnotesKey, val: footnotes)
            }
        }, priority: 50)

        conv.Register.rendererFor("a", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard element.hasClass("footnote-ref") || element.hasClass("footnote") else { return .tryNext }
            let rawHref = (try? element.attr("href")) ?? ""
            let fnId = rawHref
                .replacingOccurrences(of: "#fn:", with: "")
                .replacingOccurrences(of: "#fn", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            w.writeString("[^\(fnId)]")
            return .success
        }, priority: PriorityEarly)

        conv.Register.postRenderer({ ctx, result in
            let footnotes: [PandocFootnote]? = ctx.getState(pandocFootnotesKey)
            guard let fns = footnotes, !fns.isEmpty else { return result }
            var output = result
            for fn in fns {
                output += "\n\n[^\(fn.id)]: \(fn.text)"
            }
            return output
        }, priority: 1050)
    }
}
