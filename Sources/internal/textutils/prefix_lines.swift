import Foundation

func applyDelimiterPerLine(_ content: String, delimiter: String) -> String {
    let lines = content.components(separatedBy: "\n")
    return lines.map { line in
        let leftExtra = String(line.prefix(while: { $0.isWhitespace }))
        let withoutLeft = String(line.dropFirst(leftExtra.count))
        let rightExtra = String(withoutLeft.reversed().prefix(while: { $0.isWhitespace }).reversed())
        let trimmed = String(withoutLeft.dropLast(rightExtra.count))
        if trimmed.isEmpty {
            return leftExtra + rightExtra
        }
        return "\(leftExtra)\(delimiter)\(trimmed)\(delimiter)\(rightExtra)"
    }.joined(separator: "\n")
}
