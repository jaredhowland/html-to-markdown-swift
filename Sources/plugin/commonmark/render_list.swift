import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerListRenderers(converter: Converter) {
        converter.registerRenderer("ul") { [weak self] node, converter in
            guard let self = self else { return nil }
            let marker = self.options.bulletListMarker
            return try renderListContainer(node: node, converter: converter, isOrdered: false, marker: marker, startAt: 1)
        }

        converter.registerRenderer("ol") { [weak self] node, converter in
            guard let self = self else { return nil }
            var startAt = 1
            if let element = node as? Element,
               let startStr = try? element.attr("start"),
               let start = Int(startStr) {
                startAt = start
            }
            return try renderListContainer(node: node, converter: converter, isOrdered: true, marker: "-", startAt: startAt)
        }
    }
}

func renderListContainer(node: Node, converter: Converter, isOrdered: Bool, marker: String, startAt: Int) throws -> String {
    guard let element = node as? Element else { return "" }

    var items: [String] = []
    for child in element.getChildNodes() {
        guard let liElement = child as? Element, liElement.tagName() == "li" else { continue }
        let content = try renderChildren(liElement, converter: converter)
        var trimmed = trimConsecutiveNewlines(content).trimmingCharacters(in: .whitespacesAndNewlines)
        trimmed = trimUnnecessaryHardLineBreaks(trimmed)
        if !trimmed.isEmpty {
            items.append(trimmed)
        }
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

        if i < items.count - 1 {
            result += "\n"
        }
    }
    result += "\n\n"
    return result
}
