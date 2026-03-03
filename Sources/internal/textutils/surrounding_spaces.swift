import Foundation

/// Split a string into (leadingWhitespace, content, trailingWhitespace).
/// Mirrors Go's textutils.SurroundingSpaces.
func SurroundingSpaces(_ content: String) -> (String, String, String) {
    var right = content
    var rightExtra = ""
    while let last = right.last, last.isWhitespace {
        rightExtra = String(last) + rightExtra
        right = String(right.dropLast())
    }
    var leftExtra = ""
    var remaining = right
    while let first = remaining.first, first.isWhitespace {
        leftExtra.append(first)
        remaining = String(remaining.dropFirst())
    }
    return (leftExtra, remaining, rightExtra)
}
