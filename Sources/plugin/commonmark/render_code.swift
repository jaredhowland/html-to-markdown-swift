import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerCodeRenderers(converter: Converter) {
        let inlineCodeRenderer: NodeRenderer = { node, converter in
            if let element = node as? Element, let parent = element.parent(), parent.tagName() == "pre" {
                return extractRawText(from: element)
            }

            guard let element = node as? Element else { return nil }
            let fenceChar: Character = "`"

            let rawContent = extractRawText(from: element)

            if rawContent.trimmingCharacters(in: .whitespaces).isEmpty {
                return "`\(rawContent)`"
            }

            let content = collapseInlineCodeContent(rawContent)

            let maxCount = calculateMaxBacktickRun(in: content, char: fenceChar)
            let fenceLen = maxCount + 1
            let fence = String(repeating: fenceChar, count: fenceLen)

            var inner = content
            if inner.hasPrefix("`") { inner = " " + inner }
            if inner.hasSuffix("`") { inner = inner + " " }

            return "\(fence)\(inner)\(fence)"
        }

        for tag in ["code", "var", "samp", "kbd", "tt"] {
            converter.registerRenderer(tag, renderer: inlineCodeRenderer)
        }

        converter.registerRenderer("pre") { [weak self] node, converter in
            let fence = self?.options.codeBlockFence ?? "```"
            let fenceChar: Character = fence.first ?? "`"

            var language = ""
            var rawContent = ""
            var hasCodeChild = false

            if let element = node as? Element {
                if let codeEl = try? element.select("code").first() {
                    hasCodeChild = true
                    language = extractCodeLanguage(from: element)
                    if language.isEmpty { language = extractCodeLanguage(from: codeEl) }
                    rawContent = extractRawText(from: codeEl)
                } else {
                    language = extractCodeLanguage(from: element)
                    rawContent = extractRawText(from: element)
                }
            }

            if rawContent.hasSuffix("\n") {
                rawContent = String(rawContent.dropLast())
            }
            if !hasCodeChild && rawContent.hasPrefix("\n") {
                rawContent = String(rawContent.dropFirst())
            }

            let maxRun = calculateMaxBacktickRun(in: rawContent, char: fenceChar)
            let fenceLen = max(3, maxRun + 1)
            let actualFence = String(repeating: fenceChar, count: fenceLen)

            let markedContent = rawContent.replacingOccurrences(of: "\n", with: String(codeBlockNewlineMarker))

            return "\n\n\(actualFence)\(language)\n\(markedContent)\n\(actualFence)\n\n"
        }
    }
}

private func calculateMaxBacktickRun(in text: String, char: Character) -> Int {
    var maxRun = 0
    var current = 0
    for c in text {
        if c == char {
            current += 1
            if current > maxRun { maxRun = current }
        } else {
            current = 0
        }
    }
    return maxRun
}

/// Collapse whitespace inside inline code content (matches Go's CollapseInlineCodeContent).
private func collapseInlineCodeContent(_ content: String) -> String {
    var result = content
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\t", with: " ")
    result = result.trimmingCharacters(in: .whitespaces)
    while result.contains("  ") {
        result = result.replacingOccurrences(of: "  ", with: " ")
    }
    return result
}
