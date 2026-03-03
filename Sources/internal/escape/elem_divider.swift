/// Returns true if `-`, `_`, or `*` at charIdx forms a thematic break (divider).
/// Matches Go's IsDivider: at start of line, 3+ same chars (spaces allowed between).
func isDividerContext(chars: [Character], charIdx: Int) -> Bool {
    if !isAtStartOfLine(chars: chars, idx: charIdx) { return false }
    let ch = chars[charIdx]
    var count = 1
    var j = charIdx + 1
    while j < chars.count {
        let c = chars[j]
        if c == escapePlaceholder { j += 1; continue }
        if c == " " { j += 1; continue }
        if c == ch { count += 1; j += 1; continue }
        if c == "\n" { break }
        return false
    }
    return count >= 3
}
