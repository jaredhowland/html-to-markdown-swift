import Foundation
import SwiftSoup

public enum EmojiOutputStyle {
    case shortcode    // → :smile:
    case unicode      // → 😄 (passthrough, no transform)
}

public class EmojiPlugin: Plugin {
    public var name: String { return "emoji" }
    let outputStyle: EmojiOutputStyle
    let unicodeToShortcode: [String: String]

    public init(outputStyle: EmojiOutputStyle = .shortcode) {
        self.outputStyle = outputStyle
        // Build reverse map: unicode emoji → first shortcode
        var reverse: [String: String] = [:]
        for (shortcode, emoji) in emojiShortcodes.sorted(by: { $0.key < $1.key }) {
            if reverse[emoji] == nil {
                reverse[emoji] = shortcode
            }
        }
        self.unicodeToShortcode = reverse
    }

    public func initialize(conv: Converter) throws {
        registerEmojiImageRenderer(conv: conv)
        if outputStyle == .shortcode {
            registerUnicodeToShortcodeTransformer(conv: conv)
        }
    }
}
