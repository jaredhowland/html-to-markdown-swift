import Foundation

/// Surround content with delimiter on both sides.
/// Mirrors Go's textutils.SurroundBy.
func SurroundBy(_ content: String, chars: String) -> String {
    return chars + content + chars
}

/// Surround content with quotes, choosing single vs double based on content.
/// Mirrors Go's textutils.SurroundByQuotes.
func SurroundByQuotes(_ content: String) -> String {
    if content.isEmpty { return "" }
    let hasDouble = content.contains("\"")
    let hasSingle = content.contains("'")
    if hasDouble && hasSingle {
        let escaped = content.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
    if hasDouble {
        return "'\(content)'"
    }
    return "\"\(content)\""
}
