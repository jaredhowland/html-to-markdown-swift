import Foundation
import SwiftSoup

extension ReplacementsPlugin {
    func register(conv: Converter) {
        conv.Register.postRenderer({ ctx, result in
            applyOutsideCode(result) { text in
                var t = text

                // Scoped abbreviations — case insensitive
                t = t.replacingOccurrences(of: "(c)", with: "©", options: .caseInsensitive)
                t = t.replacingOccurrences(of: "(r)", with: "®", options: .caseInsensitive)
                t = t.replacingOccurrences(of: "(tm)", with: "™", options: .caseInsensitive)

                // Plus-minus
                t = t.replacingOccurrences(of: "+-", with: "±")

                // Ellipsis: replace 3+ consecutive dots (but not after ? or !)
                if let re = try? NSRegularExpression(pattern: "(?<![?!])\\.{3,}") {
                    let range = NSRange(t.startIndex..., in: t)
                    t = re.stringByReplacingMatches(in: t, range: range, withTemplate: "…")
                }

                // Em dash: --- (not part of 4+ run)
                if let re = try? NSRegularExpression(pattern: "(?<![-])-{3}(?![-])") {
                    let range = NSRange(t.startIndex..., in: t)
                    t = re.stringByReplacingMatches(in: t, range: range, withTemplate: "\u{2014}")
                }

                // En dash: -- (not part of 3+ run, after em dash replacement)
                if let re = try? NSRegularExpression(pattern: "(?<![-])-{2}(?![-])") {
                    let range = NSRange(t.startIndex..., in: t)
                    t = re.stringByReplacingMatches(in: t, range: range, withTemplate: "\u{2013}")
                }

                return t
            }
        }, priority: 1100)
    }
}
