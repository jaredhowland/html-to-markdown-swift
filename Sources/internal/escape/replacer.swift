import Foundation

func markEscapeCandidates(_ text: String, chars: Set<Character>) -> String {
    var result = ""
    result.reserveCapacity(text.count * 2)
    for ch in text {
        if chars.contains(ch) { result.append(escapePlaceholder) }
        result.append(ch)
    }
    return result
}

/// Legacy shim
func markEscapeCandidates(_ text: String) -> String {
    let candidates: Set<Character> = ["\\", "*", "_", "#", "+", "-", ".", "[", "]", "!", "~", "`", "=", ")"]
    return markEscapeCandidates(text, chars: candidates)
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
        // Match Go: IsFencedCode skips 2nd/3rd backtick in a 3+ opening fence at start of line.
        // IsInlineCode escapes all other backticks.
        return !isSubsequentFencedBacktick(chars: chars, charIdx: charIdx)
    case "#":
        return isAtxHeaderContext(chars: chars, charIdx: charIdx)
    case "-":
        return isUnorderedListContext(chars: chars, charIdx: charIdx)
            || isSetextHeaderContext(chars: chars, charIdx: charIdx)
            || isDividerContext(chars: chars, charIdx: charIdx)
    case "*", "+":
        return isUnorderedListContext(chars: chars, charIdx: charIdx)
            || (char == "*" && isEmphasisContext(chars: chars, charIdx: charIdx))
    case "_":
        return isEmphasisContext(chars: chars, charIdx: charIdx)
            || isDividerContext(chars: chars, charIdx: charIdx)
    case ".":
        return isOrderedListContext(chars: chars, charIdx: charIdx)
    case ")":
        return isOrderedListContext(chars: chars, charIdx: charIdx)
    case "=":
        return isSetextHeaderContext(chars: chars, charIdx: charIdx)
    case "[":
        return isOpenBracketContext(chars: chars, charIdx: charIdx)
    case "~":
        return isFencedCodeContext(chars: chars, charIdx: charIdx)
    default:
        return false
    }
}
