/// Returns true if `#` at charIdx is at start of line and forms an ATX heading
func isAtxHeaderContext(chars: [Character], charIdx: Int) -> Bool {
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

/// Returns true if `=` or `-` at charIdx would form a setext heading underline
func isSetextHeaderContext(chars: [Character], charIdx: Int) -> Bool {
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
