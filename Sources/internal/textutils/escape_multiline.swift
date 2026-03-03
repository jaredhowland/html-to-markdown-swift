import Foundation

/// Convert multi-line inline content to use Markdown hard line breaks,
/// matching Go's EscapeMultiLine.
func escapeMultiLine(_ content: String) -> String {
    let lines = content.components(separatedBy: "\n")
    guard lines.count > 1 else { return content }

    var output = ""
    for (i, line) in lines.enumerated() {
        let trimmedLeft = String(line.drop(while: { $0.isWhitespace }))

        if trimmedLeft.isEmpty {
            output += "\\\n"
            continue
        }

        let isLast = (i == lines.count - 1)
        if isLast {
            output += trimmedLeft
        } else if trimmedLeft.hasSuffix("  ") {
            output += trimmedLeft + "\n"
        } else {
            output += trimmedLeft + "  \n"
        }
    }
    return output
}
