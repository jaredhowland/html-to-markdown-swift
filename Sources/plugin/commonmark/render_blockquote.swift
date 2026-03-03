import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerBlockquoteRenderer(conv: Converter) {
        conv.Register.rendererFor("blockquote", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            var trimmed = buf.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { w.writeString(""); return .success }
            trimmed = trimConsecutiveNewlines(trimmed)
            trimmed = trimUnnecessaryHardLineBreaks(trimmed)
            let lines = trimmed.components(separatedBy: "\n")
            let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
            w.writeString("\n\n\(quoted)\n\n")
            return .success
        }, priority: PriorityStandard)
    }
}
