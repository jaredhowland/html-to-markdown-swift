import Foundation

/// Placeholder character inserted before markdown special chars during text processing.
/// Using Unicode Interlinear Annotation Anchor (U+FFF9) from Private Use Area.
let escapePlaceholder: Character = "\u{FFF9}"

/// Marker replacing \n inside code blocks to protect them from trimConsecutiveNewlines.
/// Matches Go's marker.MarkerCodeBlockNewline (U+F002).
let codeBlockNewlineMarker: Character = "\u{F002}"

/// Mark potential escape candidates in text with a placeholder prefix.
/// Only marks characters that could trigger markdown interpretation.
func markEscapeCandidates(_ text: String) -> String {
    let candidates: Set<Character> = ["\\", "*", "_", "#", "+", "-", ".", "[", "]", "!", "~", "`", "="]
    var result = ""
    result.reserveCapacity(text.count * 2)
    for char in text {
        if candidates.contains(char) {
            result.append(escapePlaceholder)
        }
        result.append(char)
    }
    return result
}

/// Post-render pass: inspect each placeholder in context and decide whether to emit `\`.
func applySmartEscaping(_ markdown: String) -> String {
    let chars = Array(markdown)
    var result = ""
    result.reserveCapacity(chars.count)

    var i = 0
    while i < chars.count {
        guard chars[i] == escapePlaceholder else {
            result.append(chars[i])
            i += 1
            continue
        }
        // chars[i] is placeholder; chars[i+1] is the candidate char
        guard i + 1 < chars.count else { i += 1; continue }
        let candidateIdx = i + 1
        let ch = chars[candidateIdx]

        if shouldEscape(chars: chars, at: i, char: ch) {
            result.append("\\")
        }
        // Skip placeholder, let the loop handle the actual char next iteration
        i += 1
    }
    return result
}

private func shouldEscape(chars: [Character], at placeholderIdx: Int, char: Character) -> Bool {
    let charIdx = placeholderIdx + 1
    switch char {
    case "\\":
        return true
    case "`":
        return true
    case "#":
        return isAtxHeaderContext(chars: chars, charIdx: charIdx)
    case "-":
        return isUnorderedListContext(chars: chars, charIdx: charIdx)
            || isSetextHeaderContext(chars: chars, charIdx: charIdx)
    case "*", "+":
        return isUnorderedListContext(chars: chars, charIdx: charIdx)
            || (char == "*" && isEmphasisContext(chars: chars, charIdx: charIdx))
    case "_":
        return isEmphasisContext(chars: chars, charIdx: charIdx)
    case ".":
        return isOrderedListContext(chars: chars, charIdx: charIdx)
    case "=":
        return isSetextHeaderContext(chars: chars, charIdx: charIdx)
    case "[":
        return isOpenBracketContext(chars: chars, charIdx: charIdx)
    default:
        return false
    }
}

// MARK: - Context checkers

/// Returns true if `#` at charIdx is at start of line and forms an ATX heading
private func isAtxHeaderContext(chars: [Character], charIdx: Int) -> Bool {
    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }

    // Count consecutive # signs (skipping placeholders)
    var hashCount = 0
    var j = charIdx
    while j < chars.count {
        if chars[j] == escapePlaceholder { j += 1; continue }
        if chars[j] == "#" { hashCount += 1; j += 1 }
        else { break }
        if hashCount > 6 { return false }
    }
    if hashCount == 0 { return false }

    // Must be followed by space, tab, newline, or end of string
    if j >= chars.count { return true }
    return chars[j] == " " || chars[j] == "\t" || chars[j] == "\n"
}

/// Returns true if `-`, `*`, or `+` at charIdx is at start of line followed by space,
/// newline, or end of string (matching Go's IsUnorderedList which uses IsSpace which
/// includes '\n', and also checks for next==0/EOF).
private func isUnorderedListContext(chars: [Character], charIdx: Int) -> Bool {
    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }
    let next = charIdx + 1
    if next >= chars.count { return true } // EOF: escape
    return chars[next] == " " || chars[next] == "\t" || chars[next] == "\n"
}

/// Returns true if `.` at charIdx is part of `N.` ordered list at start of line
private func isOrderedListContext(chars: [Character], charIdx: Int) -> Bool {
    // Char immediately before (skipping placeholder) must be a digit
    let prevIdx = charIdx - 2 // charIdx-1 is the placeholder
    guard prevIdx >= 0, chars[prevIdx].isNumber else { return false }

    // Walk back: must be only digits (and optionally spaces) from start of line
    var k = prevIdx - 1
    while k >= 0 {
        if chars[k] == escapePlaceholder { k -= 1; continue }
        if chars[k] == "\n" { break }
        if chars[k].isNumber { k -= 1; continue }
        return false // Non-digit before the digits → not ordered list
    }

    // Must be followed by space, tab, newline, or end of string (matches Go's IsSpace || next == 0)
    let next = charIdx + 1
    if next >= chars.count { return true }
    return chars[next] == " " || chars[next] == "\t" || chars[next] == "\n"
}

/// Returns true if `=` or `-` at charIdx would form a setext heading underline
private func isSetextHeaderContext(chars: [Character], charIdx: Int) -> Bool {
    let ch = chars[charIdx]
    guard ch == "=" || ch == "-" else { return false }

    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }

    // Rest of line must be all the same character
    var j = charIdx + 1
    while j < chars.count {
        if chars[j] == escapePlaceholder { j += 1; continue }
        if chars[j] == "\n" { break }
        if chars[j] != ch { return false }
        j += 1
    }

    // Previous line must be non-empty
    var lineStart = charIdx - 1
    while lineStart > 0 && chars[lineStart] != "\n" { lineStart -= 1 }
    if lineStart <= 0 { return false }
    var prevLineStart = lineStart - 1
    while prevLineStart > 0 && chars[prevLineStart] != "\n" { prevLineStart -= 1 }

    let from = prevLineStart == 0 ? 0 : prevLineStart + 1
    let to = lineStart
    for k in from..<to {
        if chars[k] != escapePlaceholder && !chars[k].isWhitespace {
            return true
        }
    }
    return false
}

/// Returns true if `*` or `_` at charIdx would form left-flanking emphasis run.
/// Only escapes left-flanking delimiters (followed by non-whitespace), matching Go's
/// IsItalicOrBold which does NOT escape right-flanking (closing) delimiters.
private func isEmphasisContext(chars: [Character], charIdx: Int) -> Bool {
    let nextIdx = charIdx + 1
    if nextIdx < chars.count {
        let nextChar = chars[nextIdx]
        if !nextChar.isWhitespace {
            return true
        }
    }
    return false
}

/// Returns true if the character at `idx` is at the start of a line (or start of string).
/// Only spaces, tabs, and placeholders may precede it on the current line.
private func isAtStartOfLine(chars: [Character], idx: Int) -> Bool {
    var i = idx - 1
    while i >= 0 {
        if chars[i] == "\n" { return true }
        if chars[i] == escapePlaceholder { i -= 1; continue }
        if chars[i] == " " || chars[i] == "\t" { i -= 1; continue }
        return false
    }
    return true
}

/// Returns true if `[` at charIdx has a matching `]` later on the same line.
private func isOpenBracketContext(chars: [Character], charIdx: Int) -> Bool {
    for j in (charIdx + 1)..<chars.count {
        if chars[j] == "\n" { return false }
        if chars[j] == "]" { return true }
    }
    return false
}
