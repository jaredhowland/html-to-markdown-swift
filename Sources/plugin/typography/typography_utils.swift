import Foundation

/// Returns ranges in `text` that are inside Markdown code regions (fenced blocks + inline code).
private func codeRanges(in text: String) -> [Range<String.Index>] {
    var ranges: [Range<String.Index>] = []
    let nsText = text as NSString

    // 1. Fenced code blocks: ```lang\n...\n``` or ~~~lang\n...\n~~~
    let fencedPattern = "(?m)^(`{3,})[^\n]*\n[\\s\\S]*?\n\\1[^\\S\n]*$|(?m)^(~{3,})[^\n]*\n[\\s\\S]*?\n\\2[^\\S\n]*$"
    if let re = try? NSRegularExpression(pattern: fencedPattern) {
        for match in re.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            if let r = Range(match.range, in: text) { ranges.append(r) }
        }
    }

    // 2. Inline code spans: `code` or ``code`` etc.
    let inlinePattern = "(`+)[\\s\\S]*?\\1(?!`)"
    if let re = try? NSRegularExpression(pattern: inlinePattern) {
        for match in re.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            if let r = Range(match.range, in: text) {
                if !ranges.contains(where: { $0.overlaps(r) }) {
                    ranges.append(r)
                }
            }
        }
    }

    return ranges.sorted { $0.lowerBound < $1.lowerBound }
}

/// Applies `transform` only to text outside Markdown code regions.
func applyOutsideCode(_ text: String, transform: (String) -> String) -> String {
    let protected = codeRanges(in: text)
    guard !protected.isEmpty else { return transform(text) }

    var result = ""
    var current = text.startIndex

    for range in protected {
        if current < range.lowerBound {
            result += transform(String(text[current..<range.lowerBound]))
        }
        result += String(text[range])  // code region: pass through unchanged
        current = range.upperBound
    }

    if current < text.endIndex {
        result += transform(String(text[current...]))
    }
    return result
}
