import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerCodeRenderers(conv: Converter) {
        let inlineCodeHandler: HandleRenderFunc = { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }

            if let parent = element.parent(), parent.tagName() == "pre" {
                w.writeString(extractRawText(from: element))
                return .success
            }

            let fenceChar: Character = "`"
            let rawContent = extractRawText(from: element)
            if rawContent.trimmingCharacters(in: .whitespaces).isEmpty {
                w.writeString("`\(rawContent)`")
                return .success
            }
            let content = collapseInlineCodeContent(rawContent)
            let maxCount = calculateMaxBacktickRun(in: content, char: fenceChar)
            let fenceLen = maxCount + 1
            let fence = String(repeating: fenceChar, count: fenceLen)
            var inner = content
            if inner.hasPrefix("`") { inner = " " + inner }
            if inner.hasSuffix("`") { inner = inner + " " }
            w.writeString("\(fence)\(inner)\(fence)")
            return .success
        }

        for tag in ["code", "var", "samp", "kbd", "tt"] {
            conv.Register.rendererFor(tag, .inline, inlineCodeHandler, priority: PriorityStandard)
        }

        conv.Register.rendererFor("pre", .block, { [weak self] ctx, w, n in
            let fence = self?.options.codeBlockFence ?? "```"
            let fenceChar: Character = fence.first ?? "`"

            var language = ""
            var rawContent = ""
            var hasCodeChild = false

            if let element = n as? Element {
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

            if rawContent.hasSuffix("\n") { rawContent = String(rawContent.dropLast()) }
            if !hasCodeChild && rawContent.hasPrefix("\n") { rawContent = String(rawContent.dropFirst()) }

            let maxRun = calculateMaxBacktickRun(in: rawContent, char: fenceChar)
            let fenceLen = max(3, maxRun + 1)
            let actualFence = String(repeating: fenceChar, count: fenceLen)
            let markedContent = rawContent.replacingOccurrences(of: "\n", with: String(codeBlockNewlineMarker))

            w.writeString("\n\n\(actualFence)\(language)\n\(markedContent)\n\(actualFence)\n\n")
            return .success
        }, priority: PriorityStandard)
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
