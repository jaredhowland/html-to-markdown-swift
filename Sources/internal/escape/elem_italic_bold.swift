/// Returns true if `*` or `_` at charIdx would form left-flanking emphasis run.
/// Only escapes left-flanking delimiters (followed by non-whitespace), matching Go's
/// IsItalicOrBold which does NOT escape right-flanking (closing) delimiters.
func isEmphasisContext(chars: [Character], charIdx: Int) -> Bool {
    let nextIdx = charIdx + 1
    if nextIdx < chars.count {
        let nextChar = chars[nextIdx]
        if !nextChar.isWhitespace {
            return true
        }
    }
    return false
}
