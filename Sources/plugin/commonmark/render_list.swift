import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerListRenderers(conv: Converter) {
        conv.Register.rendererFor("ul", .block, { [weak self] ctx, w, n in
            guard let self = self else { return .tryNext }
            let marker = self.options.bulletListMarker
            if let result = try? renderListContainer(node: n, ctx: ctx, isOrdered: false, marker: marker, startAt: 1) {
                w.writeString(result)
            }
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("ol", .block, { [weak self] ctx, w, n in
            guard let self = self else { return .tryNext }
            var startAt = 1
            if let element = n as? Element,
               let startStr = try? element.attr("start"),
               let start = Int(startStr) {
                startAt = start
            }
            if let result = try? renderListContainer(node: n, ctx: ctx, isOrdered: true, marker: "-", startAt: startAt) {
                w.writeString(result)
            }
            return .success
        }, priority: PriorityStandard)
    }
}

func renderListContainer(node: Node, ctx: Context, isOrdered: Bool, marker: String, startAt: Int) throws -> String {
    guard let element = node as? Element else { return "" }
    var items: [String] = []
    for child in element.getChildNodes() {
        guard let liElement = child as? Element, liElement.tagName() == "li" else { continue }
        let buf = StringWriter()
        ctx.renderChildNodes(buf, liElement)
        var trimmed = trimConsecutiveNewlines(buf.string).trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimUnnecessaryHardLineBreaks(trimmed)
        if !trimmed.isEmpty { items.append(trimmed) }
    }
    if items.isEmpty { return "" }
    var result = "\n\n"
    for (i, item) in items.enumerated() {
        let prefix: String
        if isOrdered {
            let lastIndex = startAt + items.count - 1
            let maxDigits = String(lastIndex).count
            let currentNum = startAt + i
            let numStr = String(currentNum)
            let paddingCount = max(0, maxDigits - numStr.count)
            let padded = String(repeating: "0", count: paddingCount) + numStr
            prefix = "\(padded). "
        } else {
            prefix = "\(marker) "
        }
        let indentCount = prefix.count
        let indent = String(repeating: " ", count: indentCount)
        let lines = item.components(separatedBy: "\n")
        let indentedMarker = String(codeBlockNewlineMarker) + indent
        let firstLine = "\(prefix)\(lines[0].replacingOccurrences(of: String(codeBlockNewlineMarker), with: indentedMarker))"
        if lines.count > 1 {
            let rest = lines.dropFirst().map { line -> String in
                let indentedLine = line.replacingOccurrences(of: String(codeBlockNewlineMarker), with: indentedMarker)
                return indentedLine.isEmpty ? indent : "\(indent)\(indentedLine)"
            }.joined(separator: "\n")
            result += "\(firstLine)\n\(rest)"
        } else {
            result += firstLine
        }
        if i < items.count - 1 { result += "\n" }
    }
    result += "\n\n"
    return result
}
