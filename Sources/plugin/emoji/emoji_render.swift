import Foundation
import SwiftSoup

extension EmojiPlugin {
    func registerEmojiImageRenderer(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { [self] ctx, w, n in
            guard let element = n as? Element,
                  element.hasClass("emoji") else { return .tryNext }

            let alt = (try? element.attr("alt")) ?? ""
            switch self.outputStyle {
            case .shortcode:
                if alt.hasPrefix(":") && alt.hasSuffix(":") {
                    w.writeString(alt)
                } else {
                    let src = (try? element.attr("src")) ?? ""
                    if let shortcode = self.shortcodeFromSrc(src) {
                        w.writeString(":\(shortcode):")
                    } else {
                        w.writeString(alt.isEmpty ? "" : alt)
                    }
                }
            case .unicode:
                if alt.hasPrefix(":") && alt.hasSuffix(":") {
                    let code = String(alt.dropFirst().dropLast())
                    if let emoji = emojiShortcodes[code] {
                        w.writeString(emoji)
                    } else {
                        w.writeString(alt)
                    }
                } else {
                    w.writeString(alt)
                }
            }
            return .success
        }, priority: PriorityEarly)
    }

    private func shortcodeFromSrc(_ src: String) -> String? {
        guard let filename = src.split(separator: "/").last else { return nil }
        let hex = String(filename.split(separator: ".").first ?? "")
        let parts = hex.split(separator: "-")
        var scalars: [Unicode.Scalar] = []
        for part in parts {
            guard let codepoint = UInt32(part, radix: 16),
                  let scalar = Unicode.Scalar(codepoint) else { return nil }
            scalars.append(scalar)
        }
        var result = ""
        for scalar in scalars { result.unicodeScalars.append(scalar) }
        return unicodeToShortcode[result]
    }
}

extension EmojiPlugin {
    func registerUnicodeToShortcodeTransformer(conv: Converter) {
        conv.Register.textTransformer({ [self] ctx, text in
            var result = ""
            result.reserveCapacity(text.count)
            var i = text.startIndex
            while i < text.endIndex {
                let ch = text[i]
                let cluster = String(ch)
                if let shortcode = self.unicodeToShortcode[cluster] {
                    result += ":\(shortcode):"
                } else {
                    result.append(ch)
                }
                i = text.index(after: i)
            }
            return result
        }, priority: PriorityEarly)
    }
}
