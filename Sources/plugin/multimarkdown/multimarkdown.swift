import Foundation
import SwiftSoup

private let mmdFootnotesKey = "mmd_footnotes"

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

    // MARK: - Subscript / Superscript

    private func registerSubSup(conv: Converter) {
        conv.Register.rendererFor("sub", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("~\(buf.string)~")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("sup", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("^\(buf.string)^")
            return .success
        }, priority: PriorityEarly)
    }

    // MARK: - Definition Lists (MMD format)

    private func registerDefinitionLists(conv: Converter) {
        conv.Register.rendererFor("dl", .block, { ctx, w, n in
            w.writeString("\n\n")
            ctx.renderChildNodes(w, n)
            w.writeString("\n\n")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("dt", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("\(buf.string)\n")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("dd", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString(":   \(buf.string)\n")
            return .success
        }, priority: PriorityEarly)
    }

    // MARK: - Image Attributes

    private func registerImageAttributes(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            let width = (try? element.attr("width")) ?? ""
            let height = (try? element.attr("height")) ?? ""
            if width.isEmpty && height.isEmpty { return .tryNext }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = defaultAssembleAbsoluteURL(rawSrc, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            if src.isEmpty { w.writeString(""); return .success }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let alt = mmdEscapeAlt(rawAlt)

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            let imgMD: String
            if title.isEmpty {
                imgMD = "![\(alt)](\(src))"
            } else {
                imgMD = "![\(alt)](\(src) \"\(title)\")"
            }

            var attrs: [String] = []
            if !width.isEmpty { attrs.append("width=\(width)px") }
            if !height.isEmpty { attrs.append("height=\(height)px") }
            let sizing = "{\(attrs.joined(separator: " "))}"

            w.writeString(imgMD + sizing)
            return .success
        }, priority: PriorityEarly)
    }

    // MARK: - Figure / Figcaption

    private func registerFigure(conv: Converter) {
        conv.Register.tagType("figure", .block, priority: PriorityEarly)

        // Suppress figcaption — the alt text on <img> already carries the caption
        conv.Register.rendererFor("figcaption", .inline, { ctx, w, n in
            return .success
        }, priority: PriorityEarly)
    }

    // MARK: - Footnotes

    private func registerFootnotes(conv: Converter) {
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

private func mmdEscapeAlt(_ alt: String) -> String {
    var result = ""
    let chars = Array(alt)
    for (i, ch) in chars.enumerated() {
        if ch == "[" || ch == "]" {
            let prevIndex = i - 1
            if prevIndex < 0 || chars[prevIndex] != "\\" {
                result.append("\\")
            }
        }
        result.append(ch)
    }
    return result
}
