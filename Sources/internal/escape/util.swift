/// Placeholder character inserted before markdown special chars during text processing.
/// Using Unicode Interlinear Annotation Anchor (U+FFF9) from Private Use Area.
let escapePlaceholder: Character = "\u{FFF9}"

/// Marker replacing \n inside code blocks to protect them from trimConsecutiveNewlines.
/// Matches Go's marker.MarkerCodeBlockNewline (U+F002).
let codeBlockNewlineMarker: Character = "\u{F002}"

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
