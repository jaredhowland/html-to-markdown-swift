/// Returns true if `.` at charIdx is part of `N.` ordered list at start of line
func isOrderedListContext(chars: [Character], charIdx: Int) -> Bool {
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

/// Returns true if `-`, `*`, or `+` at charIdx is at start of line followed by space,
/// newline, or end of string (matching Go's IsUnorderedList which uses IsSpace which
/// includes '\n', and also checks for next==0/EOF).
func isUnorderedListContext(chars: [Character], charIdx: Int) -> Bool {
    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }
    let next = charIdx + 1
    if next >= chars.count { return true } // EOF: escape
    return chars[next] == " " || chars[next] == "\t" || chars[next] == "\n"
}
