import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerHeadingRenderers(conv: Converter) {
        for level in 1...6 {
            let tag = "h\(level)"
            conv.Register.rendererFor(tag, .block, { [weak self] ctx, w, n in
                guard let self = self else { return .tryNext }
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                let content = buf.string
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { w.writeString(""); return .success }

                if self.options.headingStyle == .setext && level <= 2 {
                    let escaped = escapeMultiLine(trimmed)
                    let lines = escaped.components(separatedBy: "\n")
                    let maxWidth = max(3, lines.map { $0.count }.max() ?? 3)
                    let underlineChar: Character = level == 1 ? "=" : "-"
                    let underline = String(repeating: underlineChar, count: maxWidth)
                    w.writeString("\n\n\(escaped)\n\(underline)\n\n")
                } else {
                    let flat = trimmed
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                    let collapsed = escapePoundSignAtEnd(collapseWhitespace(flat))
                    let hashes = String(repeating: "#", count: level)
                    w.writeString("\n\n\(hashes) \(collapsed)\n\n")
                }
                return .success
            }, priority: PriorityStandard)
        }
    }

    private func escapePoundSignAtEnd(_ s: String) -> String {
        let chars = Array(s)
        let n = chars.count
        guard n >= 1, chars[n - 1] == "#" else { return s }
        if n >= 3 && chars[n - 3] == "\\" {
            return s
        }
        if n >= 2 && chars[n - 2] == escapePlaceholder {
            var result = chars
            result[n - 2] = "\\"
            return String(result)
        }
        return s.dropLast() + "\\#"
    }
}
