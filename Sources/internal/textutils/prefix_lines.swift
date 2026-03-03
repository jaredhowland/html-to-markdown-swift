import Foundation

/// Prefix every line with repl.
/// Mirrors Go's textutils.PrefixLines.
func PrefixLines(_ source: String, repl: String) -> String {
    var result = repl
    for ch in source {
        result.append(ch)
        if ch == "\n" {
            result += repl
        }
    }
    return result
}

/// Put the delimiter at the start and end of each non-empty line.
/// Whitespace at the edges of each line goes OUTSIDE the delimiters.
/// Mirrors Go's textutils.DelimiterForEveryLine.
func DelimiterForEveryLine(_ text: String, delimiter: String) -> String {
    return applyDelimiterPerLine(text, delimiter: delimiter)
}

func applyDelimiterPerLine(_ content: String, delimiter: String) -> String {
    let lines = content.components(separatedBy: "\n")
    return lines.map { line in
        let leftExtra = String(line.prefix(while: { $0.isWhitespace }))
        let withoutLeft = String(line.dropFirst(leftExtra.count))
        let rightExtra = String(withoutLeft.reversed().prefix(while: { $0.isWhitespace }).reversed())
        let trimmed = String(withoutLeft.dropLast(rightExtra.count))
        if trimmed.isEmpty {
            return leftExtra + rightExtra
        }
        return "\(leftExtra)\(delimiter)\(trimmed)\(delimiter)\(rightExtra)"
    }.joined(separator: "\n")
}
