import Foundation
import SwiftSoup

public class TaskListItemsPlugin: Plugin {
    public var name: String { return "task-list-items" }
    public init() {}

    public func initialize(conv: Converter) throws {
        registerTaskListItems(conv: conv)
    }
}

extension TaskListItemsPlugin {
    func registerTaskListItems(conv: Converter) {
        // Pre-render at priority 50: replace <input type="checkbox"> with custom element
        // before BasePlugin removes <input> at priority 100
        conv.Register.preRenderer({ ctx, doc in
            guard let checkboxes = try? doc.select("li input[type=checkbox]") else { return }
            for input in checkboxes {
                let checked = input.hasAttr("checked")
                let placeholder = try? Element(Tag.valueOf("task-list-checkbox"), "")
                if checked { try? placeholder?.attr("checked", "") }
                if let next = input.nextSibling() as? TextNode {
                    let trimmed = next.text().replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
                    try? next.text(trimmed)
                }
                if let placeholder = placeholder {
                    try? input.replaceWith(placeholder)
                }
            }
        }, priority: 50)

        // Render the custom element (bypasses text escaping so "[" isn't escaped)
        conv.Register.rendererFor("task-list-checkbox", .inline, { ctx, w, n in
            let checked = (n as? Element)?.hasAttr("checked") ?? false
            w.writeString(checked ? "[x] " : "[ ] ")
            return .success
        }, priority: PriorityEarly)
    }
}
