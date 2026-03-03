import Foundation
import SwiftSoup

public class StrikethroughPlugin: Plugin {
    public init() {}
    public var name: String { return "strikethrough" }

    public func initialize(conv: Converter) throws {
        conv.Register.escapedChar("~")

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "~" else { return -1 }
            return isFencedCodeContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        for tag in ["strike", "s", "del"] {
            conv.Register.rendererFor(tag, .inline, { ctx, w, n in
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                let content = applyDelimiterPerLine(buf.string, delimiter: "~~")
                w.writeString(content)
                return .success
            }, priority: PriorityStandard)
        }
    }
}
