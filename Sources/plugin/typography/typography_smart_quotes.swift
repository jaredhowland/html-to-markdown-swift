import Foundation
import SwiftSoup

extension SmartQuotesPlugin {
    func register(conv: Converter) {
        let quoteStyle = self.style

        // <q> element → typographic double quotes (locale-aware)
        conv.Register.rendererFor("q", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("\(quoteStyle.openDouble)\(buf.string)\(quoteStyle.closeDouble)")
            return .success
        }, priority: PriorityEarly)

        // Post-render: convert straight quotes to typographic quotes outside code
        conv.Register.postRenderer({ [weak self] ctx, result in
            guard let self = self else { return result }
            return applyOutsideCode(result) { text in
                self.applySmartQuotes(to: text)
            }
        }, priority: 1100)
    }

    func applySmartQuotes(to text: String) -> String {
        var chars = Array(text)
        var doubleStack: [Int] = []
        var singleStack: [Int] = []

        for i in 0..<chars.count {
            let c = chars[i]
            guard c == "\"" || c == "'" else { continue }

            let prevChar: Character = i > 0 ? chars[i - 1] : " "
            let nextChar: Character = i + 1 < chars.count ? chars[i + 1] : " "

            let prevIsSpace = prevChar.isWhitespace || prevChar == "\n" || prevChar == "\r"
            let nextIsSpace = nextChar.isWhitespace || nextChar == "\n" || nextChar == "\r"
            let prevIsWord  = prevChar.isLetter || prevChar.isNumber
            let nextIsWord  = nextChar.isLetter || nextChar.isNumber
            let prevIsPunct = !prevIsWord && !prevIsSpace
            let nextIsPunct = !nextIsWord && !nextIsSpace

            var canOpen  = !nextIsSpace
            var canClose = !prevIsSpace

            if nextIsPunct && !(prevIsSpace || prevIsPunct) { canOpen = false }
            if prevIsPunct && !(nextIsSpace || nextIsPunct) { canClose = false }

            if c == "\"" {
                if canClose && !doubleStack.isEmpty {
                    chars[doubleStack.removeLast()] = style.openDouble
                    chars[i] = style.closeDouble
                } else if canOpen {
                    doubleStack.append(i)
                } else if canClose {
                    chars[i] = style.closeDouble
                }
            } else { // single quote '
                // Apostrophe: between two word characters
                if prevIsWord && nextIsWord {
                    chars[i] = style.closeSingle
                    continue
                }
                if canClose && !singleStack.isEmpty {
                    chars[singleStack.removeLast()] = style.openSingle
                    chars[i] = style.closeSingle
                } else if canOpen {
                    singleStack.append(i)
                } else if canClose {
                    chars[i] = style.closeSingle
                }
            }
        }
        return String(chars)
    }
}
