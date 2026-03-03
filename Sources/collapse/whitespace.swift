import Foundation

/// Collapse consecutive whitespace characters (space, tab, newline, CR) to a single space.
/// Matches Go's replaceAnyWhitespaceWithSpace.
func replaceAnyWhitespaceWithSpace(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    var prevWasSpace = false
    for ch in text {
        if ch == " " || ch == "\t" || ch == "\n" || ch == "\r" {
            if !prevWasSpace {
                result.append(" ")
                prevWasSpace = true
            }
        } else {
            result.append(ch)
            prevWasSpace = false
        }
    }
    return result
}

/// Trim consecutive newlines to at most 2, matching Go's TrimConsecutiveNewlines algorithm.
/// Spaces before a newline are consumed as part of that newline's sequence.
/// When a third or more newline is encountered, the excess newlines and their preceding spaces are dropped.
func trimConsecutiveNewlines(_ text: String) -> String {
    var result = ""
    result.reserveCapacity(text.count)
    var spaceBuffer = ""
    var newlineCount = 0

    for ch in text {
        if ch == "\n" {
            newlineCount += 1
            if newlineCount <= 2 {
                result.append(contentsOf: spaceBuffer)
                result.append(ch)
            }
            spaceBuffer = ""
        } else if ch == " " {
            spaceBuffer.append(ch)
        } else {
            newlineCount = 0
            result.append(contentsOf: spaceBuffer)
            result.append(ch)
            spaceBuffer = ""
        }
    }
    result.append(contentsOf: spaceBuffer)
    return result
}

/// Remove hard line breaks ("  \n") immediately before empty lines, matching Go's TrimUnnecessaryHardLineBreaks.
func trimUnnecessaryHardLineBreaks(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(of: "  \n\n", with: "\n\n")
    result = result.replacingOccurrences(of: "  \n  \n", with: "\n\n")
    result = result.replacingOccurrences(of: "  \n \n", with: "\n\n")
    return result
}

/// Collapse inline whitespace (multiple spaces/tabs to single space)
func collapseWhitespace(_ text: String) -> String {
    let pattern = "[ \\t]+"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ").trimmingCharacters(in: .whitespaces)
    }
    return text.trimmingCharacters(in: .whitespaces)
}

/// Collapse runs of 2+ consecutive spaces that are not part of a Markdown hard line break ("  \n").
/// Used in block element renderers to normalize spaces left behind by empty inline elements.
func collapseInlineSpaces(_ text: String) -> String {
    // Pattern: 2+ spaces not preceded by \n (to protect indentation) and not followed by \n (to protect "  \n" hard breaks)
    let pattern = "(?<!\\n)  +(?!\\n)"
    if let regex = try? NSRegularExpression(pattern: pattern) {
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
    }
    return text
}
