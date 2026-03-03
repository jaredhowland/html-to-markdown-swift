/// Returns true if `` ` `` or `~` at charIdx opens a fenced code block.
/// Matches Go's IsFencedCode: at start of line, 3+ consecutive same chars (no spaces).
func isFencedCodeContext(chars: [Character], charIdx: Int) -> Bool {
    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }
    let ch = chars[charIdx]
    var count = 1
    var j = charIdx + 1
    while j < chars.count {
        if chars[j] == escapePlaceholder { j += 1; continue }
        if chars[j] == ch { count += 1; j += 1 } else { break }
    }
    return count >= 3
}

/// Returns true if this backtick is the 2nd or later in a 3+ fenced opening at start of line.
/// Matches Go's IsFencedCode skip behaviour: only the first backtick gets escaped.
func isSubsequentFencedBacktick(chars: [Character], charIdx: Int) -> Bool {
    var prevIdx = charIdx - 1
    while prevIdx >= 0, chars[prevIdx] == escapePlaceholder { prevIdx -= 1 }
    guard prevIdx >= 0, chars[prevIdx] == "`" else { return false }

    // Find the first backtick in this consecutive run
    var firstIdx = prevIdx
    while true {
        var p = firstIdx - 1
        while p >= 0, chars[p] == escapePlaceholder { p -= 1 }
        if p >= 0, chars[p] == "`" { firstIdx = p } else { break }
    }

    guard isAtStartOfLine(chars: chars, idx: firstIdx) else { return false }

    // Count the whole run; must be 3+
    var count = 1
    var j = firstIdx + 1
    while j < chars.count {
        if chars[j] == escapePlaceholder { j += 1; continue }
        if chars[j] == "`" { count += 1; j += 1 } else { break }
    }
    return count >= 3
}
