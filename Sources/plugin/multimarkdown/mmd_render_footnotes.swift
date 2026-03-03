import Foundation
import SwiftSoup

extension MultiMarkdownPlugin {
    func registerFootnotes(conv: Converter) {
        // Pre-renderer: extract footnote definitions and remove them from DOM
        conv.Register.preRenderer({ ctx, doc in
            var footnotes: [MMDFootnote] = []

            if let divs = try? doc.select("div.footnotes") {
                for div in divs {
                    if let items = try? div.select("li[id^=fn:]") {
                        for li in items {
                            let rawId = li.id()
                            let fnId = rawId.replacingOccurrences(of: "fn:", with: "")
                            // Remove return links to avoid polluting the text
                            if let reverseLinks = try? li.select("a.reversefootnote") {
                                for link in reverseLinks { try? link.remove() }
                            }
                            let text = (try? li.text()) ?? ""
                            footnotes.append(MMDFootnote(id: fnId, text: text))
                        }
                    }
                    try? div.remove()
                }
            }

            // Remove any trailing <hr> that was part of the footnotes section
            if let body = doc.body(), let hrs = try? body.select("hr") {
                for hr in hrs.array().reversed() {
                    if (try? hr.nextElementSibling()) == nil {
                        try? hr.remove()
                    }
                    break
                }
            }

            if !footnotes.isEmpty {
                ctx.setState(mmdFootnotesKey, val: footnotes)
            }
        }, priority: 50)

        // Inline renderer: replace footnote <a> with [^id]
        conv.Register.rendererFor("a", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard element.hasClass("footnote") else { return .tryNext }
            let rawHref = (try? element.attr("href")) ?? ""
            let fnId = rawHref
                .replacingOccurrences(of: "#fn:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            w.writeString("[^\(fnId)]")
            return .success
        }, priority: PriorityEarly)

        // Post-renderer: append footnote definitions at the bottom
        conv.Register.postRenderer({ ctx, result in
            let footnotes: [MMDFootnote]? = ctx.getState(mmdFootnotesKey)
            guard let fns = footnotes, !fns.isEmpty else { return result }
            var output = result
            for fn in fns {
                output += "\n\n[^\(fn.id)]: \(fn.text)"
            }
            return output
        }, priority: 1050)
    }
}
