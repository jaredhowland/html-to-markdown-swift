import Foundation

/// Collapse whitespace inside inline code content.
/// Replaces newlines/tabs with spaces, collapses multiple spaces, trims.
/// Mirrors Go's textutils.CollapseInlineCodeContent.
func CollapseInlineCodeContent(_ content: String) -> String {
    var result = content
    result = result.replacingOccurrences(of: "\n", with: " ")
    result = result.replacingOccurrences(of: "\t", with: " ")
    result = result.trimmingCharacters(in: .whitespaces)

    var out = ""
    var lastWasSpace = false
    for ch in result {
        if ch == " " {
            if lastWasSpace { continue }
            lastWasSpace = true
        } else {
            lastWasSpace = false
        }
        out.append(ch)
    }
    return out
}
