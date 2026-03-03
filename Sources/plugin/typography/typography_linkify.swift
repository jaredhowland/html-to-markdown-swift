import Foundation
import SwiftSoup

extension LinkifyPlugin {
    func register(conv: Converter) {
        conv.Register.postRenderer({ ctx, result in
            applyOutsideCode(result) { text in
                linkifyText(text)
            }
        }, priority: 1100)
    }
}

private func linkifyText(_ text: String) -> String {
    // Match bare http(s):// URLs not already inside a Markdown link [text](URL)
    let pattern = "https?://[^\\s\\]\\[<>\"'`\\(\\)]+"
    guard let re = try? NSRegularExpression(pattern: pattern) else { return text }

    let nsRange = NSRange(text.startIndex..., in: text)
    // Process matches in REVERSE order to preserve string indices during replacement
    let matches = re.matches(in: text, range: nsRange).reversed()

    var result = text
    for match in matches {
        guard let range = Range(match.range, in: result) else { continue }

        // Check if this URL is already inside a Markdown link: ](url)
        // The character immediately before the URL would be '(' and before that ']'
        if range.lowerBound > result.startIndex {
            let oneBefore = result.index(before: range.lowerBound)
            if result[oneBefore] == "(" {
                // Check for ] two positions back
                if oneBefore > result.startIndex {
                    let twoBefore = result.index(before: oneBefore)
                    if result[twoBefore] == "]" {
                        continue  // Already a Markdown link — skip
                    }
                }
                // Just ( before it (could be in other contexts) — skip to be safe
                continue
            }
        }

        var url = String(result[range])

        // Strip trailing punctuation that's likely not part of the URL, keep it as suffix
        let trailingPunct: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", "\"", "'"]
        var suffix = ""
        while let last = url.last, trailingPunct.contains(last) {
            suffix = String(last) + suffix
            url = String(url.dropLast())
        }

        guard !url.isEmpty else { continue }

        let replacement = "[\(url)](\(url))\(suffix)"
        result.replaceSubrange(range, with: replacement)
    }
    return result
}
