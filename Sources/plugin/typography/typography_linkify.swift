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
    // Match bare URLs — allow parens so Wikipedia-style URLs work
    let pattern = "https?://[^\\s\\]\\[<>\"'`]+"
    guard let re = try? NSRegularExpression(pattern: pattern) else { return text }

    let nsRange = NSRange(text.startIndex..., in: text)
    // Process matches in REVERSE order to preserve string indices during replacement
    let matches = re.matches(in: text, range: nsRange).reversed()

    var result = text
    for match in matches {
        guard let range = Range(match.range, in: result) else { continue }

        // Only skip if preceded by ]( — i.e., already inside a Markdown link [text](URL)
        if range.lowerBound >= result.index(result.startIndex, offsetBy: 2) {
            let oneBefore = result.index(before: range.lowerBound)
            let twoBefore = result.index(before: oneBefore)
            if result[twoBefore] == "]" && result[oneBefore] == "(" {
                continue  // Already a Markdown link — skip
            }
        }

        var url = String(result[range])
        var suffix = ""

        // Strip simple trailing punctuation (not parens yet), preserving as suffix
        let simplePunct: Set<Character> = [".", ",", ";", ":", "!", "?"]
        while let last = url.last, simplePunct.contains(last) {
            suffix = String(last) + suffix
            url = String(url.dropLast())
        }

        // Balance parentheses: strip trailing ) while unmatched
        while url.last == ")" {
            let opens = url.filter { $0 == "(" }.count
            let closes = url.filter { $0 == ")" }.count
            if closes > opens {
                suffix = ")" + suffix
                url = String(url.dropLast())
            } else {
                break
            }
        }

        // Also strip remaining trailing punct after paren balancing
        while let last = url.last, simplePunct.contains(last) {
            suffix = String(last) + suffix
            url = String(url.dropLast())
        }

        // Require URL has content after ://
        guard let schemeEnd = url.range(of: "://"),
              url[schemeEnd.upperBound...].count >= 1 else { continue }

        let replacement = "[\(url)](\(url))\(suffix)"
        result.replaceSubrange(range, with: replacement)
    }
    return result
}
