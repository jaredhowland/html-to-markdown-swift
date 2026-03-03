import Foundation
import SwiftSoup

public class GFMPlugin: Plugin {
    public var name: String { return "gfm" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        registerTaskListItems(conv: conv)
        registerDefinitionLists(conv: conv)
        registerDetailsSummary(conv: conv)
        registerSubSup(conv: conv)
        registerAbbr(conv: conv)
    }

    // MARK: - Task list items

    private func registerTaskListItems(conv: Converter) {
        // Must run at priority < 100 (before BasePlugin removes <input> at priority 100).
        // Replace <input type="checkbox"> with a custom <gfm-task-checkbox> element so
        // the "[x] " / "[ ] " prefix is written directly to the output writer and bypasses
        // text-transformation escaping (which would turn "[" into "\[").
        conv.Register.preRenderer({ ctx, doc in
            guard let checkboxes = try? doc.select("li > input[type=checkbox]") else { return }
            for input in checkboxes {
                let checked = input.hasAttr("checked")
                let placeholder = try? Element(Tag.valueOf("gfm-task-checkbox"), "")
                if checked { try? placeholder?.attr("checked", "") }
                // Trim leading space from the next sibling text node
                if let next = input.nextSibling() as? TextNode {
                    let trimmed = next.text().replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
                    try? next.text(trimmed)
                }
                if let placeholder = placeholder {
                    try? input.replaceWith(placeholder)
                }
            }
        }, priority: 50)

        // Render the custom element directly (bypasses text escaping)
        conv.Register.rendererFor("gfm-task-checkbox", .inline, { ctx, w, n in
            let checked = (n as? Element)?.hasAttr("checked") ?? false
            w.writeString(checked ? "[x] " : "[ ] ")
            return .success
        }, priority: PriorityEarly)
    }

    // MARK: - Definition lists

    private func registerDefinitionLists(conv: Converter) {
        conv.Register.rendererFor("dl", .block, { ctx, w, n in
            w.writeString("\n\n")
            ctx.renderChildNodes(w, n)
            w.writeString("\n\n")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("dt", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("**\(buf.string)**\n")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("dd", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString(": \(buf.string)\n")
            return .success
        }, priority: PriorityStandard)
    }

    // MARK: - Details / Summary

    private func registerDetailsSummary(conv: Converter) {
        conv.Register.rendererFor("details", .block, { ctx, w, n in
            w.writeString("\n\n")
            ctx.renderChildNodes(w, n)
            w.writeString("\n\n")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("summary", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("**\(buf.string)**\n\n")
            return .success
        }, priority: PriorityStandard)
    }

    // MARK: - Subscript / Superscript

    private func registerSubSup(conv: Converter) {
        conv.Register.rendererFor("sub", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("<sub>\(buf.string)</sub>")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("sup", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("<sup>\(buf.string)</sup>")
            return .success
        }, priority: PriorityStandard)
    }

    // MARK: - Abbreviations

    private func registerAbbr(conv: Converter) {
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
