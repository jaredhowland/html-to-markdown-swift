import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerBlockquoteRenderer(converter: Converter) {
        converter.registerRenderer("blockquote") { node, converter in
            let content = try renderChildren(node, converter: converter)
            var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return "" }
            trimmed = trimConsecutiveNewlines(trimmed)
            trimmed = trimUnnecessaryHardLineBreaks(trimmed)
            let lines = trimmed.components(separatedBy: "\n")
            let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
            return "\n\n\(quoted)\n\n"
        }
    }
}
