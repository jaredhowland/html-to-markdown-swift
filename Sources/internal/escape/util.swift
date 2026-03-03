import Foundation

// Use the canonical marker constants (mirrors Go's marker package)
let escapePlaceholder: Character = MarkerEscaping
let codeBlockNewlineMarker: Character = MarkerCodeBlockNewline

/// Returns true if the character at `idx` is at the start of a line (or start of string).
/// Only spaces, tabs, and placeholders may precede it on the current line.
func isAtStartOfLine(chars: [Character], idx: Int) -> Bool {
    var i = idx - 1
    while i >= 0 {
        if chars[i] == "\n" { return true }
        if chars[i] == escapePlaceholder { i -= 1; continue }
        if chars[i] == " " || chars[i] == "\t" { i -= 1; continue }
        return false
    }
    return true
}
