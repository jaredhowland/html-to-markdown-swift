/// Returns true if `[` at charIdx has a matching `]` later on the same line.
func isOpenBracketContext(chars: [Character], charIdx: Int) -> Bool {
    for j in (charIdx + 1)..<chars.count {
        if chars[j] == "\n" { return false }
        if chars[j] == "]" { return true }
    }
    return false
}
