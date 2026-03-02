import Foundation
import SwiftSoup

/// Heading style for Markdown output
public enum HeadingStyle: String {
    case atx = "atx"       // # Heading
    case setext = "setext" // Heading\n=======
}

/// Link rendering behavior for empty href or content
public enum LinkBehavior: String {
    case render = "render"
    case skip = "skip"
}

/// Options for the Commonmark plugin
public struct CommonmarkOptions {
    /// Delimiter for italic: "*" (default) or "_"
    public var emDelimiter: String = "*"
    /// Delimiter for bold: "**" (default) or "__"
    public var strongDelimiter: String = "**"
    /// Horizontal rule: "* * *" (default), "---", "___", etc.
    public var horizontalRule: String = "* * *"
    /// Bullet list marker: "-" (default), "+", or "*"
    public var bulletListMarker: String = "-"
    /// Code block fence: "```" (default) or "~~~"
    public var codeBlockFence: String = "```"
    /// Heading style: .atx (default) or .setext
    public var headingStyle: HeadingStyle = .atx
    /// How to handle links with empty href
    public var linkEmptyHrefBehavior: LinkBehavior = .render
    /// How to handle links with empty content
    public var linkEmptyContentBehavior: LinkBehavior = .render

    public init() {}
}

/// Error thrown when CommonmarkOptions has invalid values
public struct ValidateConfigError: Error, LocalizedError {
    public let field: String
    public let value: String
    public let message: String

    public var errorDescription: String? {
        return "invalid value for \(field):\"\(value)\" \(message)"
    }
}

/// Validate CommonmarkOptions, throws ValidateConfigError on invalid values
func validateCommonmarkOptions(_ opts: CommonmarkOptions) throws {
    if opts.emDelimiter != "*" && opts.emDelimiter != "_" {
        throw ValidateConfigError(field: "EmDelimiter", value: opts.emDelimiter, message: "must be exactly 1 character of \"*\" or \"_\"")
    }
    if opts.strongDelimiter != "**" && opts.strongDelimiter != "__" {
        throw ValidateConfigError(field: "StrongDelimiter", value: opts.strongDelimiter, message: "must be exactly 2 characters of \"**\" or \"__\"")
    }
    let validHR = opts.horizontalRule.allSatisfy { $0 == "*" || $0 == "-" || $0 == "_" || $0 == " " }
    let hrCharsOnly = opts.horizontalRule.filter { $0 != " " }
    if !validHR || hrCharsOnly.count < 3 || (Set(hrCharsOnly).count > 1) {
        throw ValidateConfigError(field: "HorizontalRule", value: opts.horizontalRule, message: "must be at least 3 characters of \"*\", \"_\" or \"-\"")
    }
    if opts.bulletListMarker != "-" && opts.bulletListMarker != "+" && opts.bulletListMarker != "*" {
        throw ValidateConfigError(field: "BulletListMarker", value: opts.bulletListMarker, message: "must be one of \"-\", \"+\" or \"*\"")
    }
    if opts.codeBlockFence != "```" && opts.codeBlockFence != "~~~" {
        throw ValidateConfigError(field: "CodeBlockFence", value: opts.codeBlockFence, message: "must be one of \"```\" or \"~~~\"")
    }
    if opts.headingStyle != .atx && opts.headingStyle != .setext {
        throw ValidateConfigError(field: "HeadingStyle", value: opts.headingStyle.rawValue, message: "must be one of \"atx\" or \"setext\"")
    }
}

/// Plugin implementing CommonMark Markdown specification
class CommonmarkPlugin: Plugin {
    let options: CommonmarkOptions
    private var validationError: Error?

    init(options: CommonmarkOptions = CommonmarkOptions()) {
        self.options = options
        do {
            try validateCommonmarkOptions(options)
        } catch {
            self.validationError = error
        }
    }

    func register(with converter: Converter) {
        registerBoldItalicRenderers(converter: converter)
        registerLinkRenderers(converter: converter)
        registerImageRenderers(converter: converter)
        registerCodeRenderers(converter: converter)
        registerBlockquoteRenderer(converter: converter)
        registerListRenderers(converter: converter)
        registerHeadingRenderers(converter: converter)
        registerDividerRenderer(converter: converter)
        registerBreakRenderer(converter: converter)
        registerCommentRenderer(converter: converter)
    }

    func handlePreRender(node: Node, converter: Converter) throws {
        if let err = validationError {
            throw ConversionError.pluginError("error while initializing \"commonmark\" plugin: \(err.localizedDescription)")
        }
    }

    // MARK: - Bold and Italic Rendering

    private func registerBoldItalicRenderers(converter: Converter) {
        for tag in ["strong", "b"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                let delimiter = self?.options.strongDelimiter ?? "**"
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
        for tag in ["em", "i"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                let delimiter = self?.options.emDelimiter ?? "*"
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
    }

    // MARK: - Link Rendering

    private func registerLinkRenderers(converter: Converter) {
        converter.registerRenderer("a") { [weak self] node, converter in
            guard let element = node as? Element else { return nil }
            guard let self = self else { return nil }

            let href = (try? element.attr("href")) ?? ""
            let hrefTrimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)

            if hrefTrimmed.isEmpty && self.options.linkEmptyHrefBehavior == .skip {
                return try renderChildren(node, converter: converter)
            }

            let content = try renderChildren(node, converter: converter)
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmedContent.isEmpty && self.options.linkEmptyContentBehavior == .skip {
                return ""
            }

            var url = hrefTrimmed
            if let domain = converter.getOptions().baseDomain, !hrefTrimmed.isEmpty && !hrefTrimmed.hasPrefix("http") && !hrefTrimmed.hasPrefix("//") {
                let base = domain.hasSuffix("/") ? String(domain.dropLast()) : domain
                let path = hrefTrimmed.hasPrefix("/") ? hrefTrimmed : "/" + hrefTrimmed
                url = base + path
            }

            let title = ((try? element.attr("title")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            let leftPad = content.prefix(while: { $0 == " " })
            let rightPad = String(content.reversed().prefix(while: { $0 == " " }).reversed())
            let innerContent = trimmedContent

            if title.isEmpty {
                return "\(leftPad)[\(innerContent)](\(url))\(rightPad)"
            } else {
                return "\(leftPad)[\(innerContent)](\(url) \"\(title)\")\(rightPad)"
            }
        }
    }

    // MARK: - Image Rendering

    private func registerImageRenderers(converter: Converter) {
        converter.registerRenderer("img") { node, converter in
            guard let element = node as? Element else { return nil }

            let src = ((try? element.attr("src")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if src.isEmpty { return "" }

            var url = src
            if let domain = converter.getOptions().baseDomain, !src.hasPrefix("http") && !src.hasPrefix("//") {
                let base = domain.hasSuffix("/") ? String(domain.dropLast()) : domain
                let path = src.hasPrefix("/") ? src : "/" + src
                url = base + path
            }

            let alt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let title = ((try? element.attr("title")) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

            if title.isEmpty {
                return "![\(alt)](\(url))"
            } else {
                return "![\(alt)](\(url) \"\(title)\")"
            }
        }
    }

    // MARK: - Code Rendering

    private func registerCodeRenderers(converter: Converter) {
        converter.registerRenderer("code") { [weak self] node, converter in
            if let element = node as? Element, let parent = try? element.parent(), parent.tagName() == "pre" {
                return try renderChildren(node, converter: converter)
            }

            let fenceChar: Character = "`"
            let content = try renderChildren(node, converter: converter)

            if content.trimmingCharacters(in: .whitespaces).isEmpty {
                return "`\(content)`"
            }

            let maxCount = calculateMaxBacktickRun(in: content, char: fenceChar)
            let fenceLen = maxCount + 1
            let fence = String(repeating: fenceChar, count: fenceLen)

            var inner = content
            if inner.hasPrefix("`") { inner = " " + inner }
            if inner.hasSuffix("`") { inner = inner + " " }

            return "\(fence)\(inner)\(fence)"
        }

        converter.registerRenderer("pre") { [weak self] node, converter in
            let fence = self?.options.codeBlockFence ?? "```"
            let fenceChar: Character = fence.first ?? "`"

            var language = ""
            var rawContent = ""

            if let element = node as? Element {
                if let codeEl = try? element.select("code").first() {
                    language = extractCodeLanguage(from: codeEl)
                    rawContent = extractRawText(from: codeEl)
                } else {
                    rawContent = extractRawText(from: element)
                }
            }

            if rawContent.hasSuffix("\n") {
                rawContent = String(rawContent.dropLast())
            }

            let maxRun = calculateMaxBacktickRun(in: rawContent, char: fenceChar)
            let fenceLen = max(3, maxRun + 1)
            let actualFence = String(repeating: fenceChar, count: fenceLen)

            return "\n\n\(actualFence)\(language)\n\(rawContent)\n\(actualFence)\n\n"
        }
    }

    // MARK: - Blockquote Rendering

    private func registerBlockquoteRenderer(converter: Converter) {
        converter.registerRenderer("blockquote") { node, converter in
            let content = try renderChildren(node, converter: converter)
            var trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            trimmed = trimConsecutiveNewlines(trimmed)
            let lines = trimmed.components(separatedBy: "\n")
            let quoted = lines.map { "> \($0)" }.joined(separator: "\n")
            return "\n\n\(quoted)\n\n"
        }
    }

    // MARK: - List Rendering

    private func registerListRenderers(converter: Converter) {
        converter.registerRenderer("ul") { [weak self] node, converter in
            guard let self = self else { return nil }
            let marker = self.options.bulletListMarker
            return try renderListContainer(node: node, converter: converter, isOrdered: false, marker: marker, startAt: 1)
        }

        converter.registerRenderer("ol") { node, converter in
            var startAt = 1
            if let element = node as? Element,
               let startStr = try? element.attr("start"),
               let start = Int(startStr) {
                startAt = start
            }
            return try renderListContainer(node: node, converter: converter, isOrdered: true, marker: "-", startAt: startAt)
        }
    }

    // MARK: - Heading Rendering

    private func registerHeadingRenderers(converter: Converter) {
        for level in 1...6 {
            let tag = "h\(level)"
            converter.registerRenderer(tag) { [weak self] node, converter in
                guard let self = self else { return nil }
                let content = try renderChildren(node, converter: converter)
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return "" }

                if self.options.headingStyle == .setext && level <= 2 {
                    let lines = trimmed.components(separatedBy: "\n")
                    let maxWidth = max(3, lines.map { $0.count }.max() ?? 3)
                    let underlineChar: Character = level == 1 ? "=" : "-"
                    let underline = String(repeating: underlineChar, count: maxWidth)
                    return "\n\n\(trimmed)\n\(underline)\n\n"
                } else {
                    let flat = trimmed
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                    let collapsed = collapseWhitespace(flat)
                    let hashes = String(repeating: "#", count: level)
                    return "\n\n\(hashes) \(collapsed)\n\n"
                }
            }
        }
    }

    // MARK: - Divider Rendering

    private func registerDividerRenderer(converter: Converter) {
        converter.registerRenderer("hr") { [weak self] _, _ in
            let rule = self?.options.horizontalRule ?? "* * *"
            return "\n\n\(rule)\n\n"
        }
    }

    // MARK: - Break Rendering

    private func registerBreakRenderer(converter: Converter) {
        converter.registerRenderer("br") { _, _ in
            return "  \n"
        }
    }

    // MARK: - Comment Rendering

    private func registerCommentRenderer(converter: Converter) {
        converter.registerRenderer("#comment") { _, _ in
            return ""
        }
    }
}

// MARK: - Helpers

private func applyDelimiterPerLine(_ content: String, delimiter: String) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return "\(delimiter)\(delimiter)" }

    if !trimmed.contains("\n") {
        return "\(delimiter)\(trimmed)\(delimiter)"
    }

    let lines = trimmed.components(separatedBy: "\n")
    return lines.map { line in
        let t = line.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return "" }
        return "\(delimiter)\(t)\(delimiter)"
    }.joined(separator: "\n")
}

func extractCodeLanguage(from element: Element) -> String {
    let cls = (try? element.attr("class")) ?? ""
    let parts = cls.components(separatedBy: " ")
    for part in parts {
        if part.hasPrefix("language-") {
            return String(part.dropFirst("language-".count))
        }
        if part.hasPrefix("lang-") {
            return String(part.dropFirst("lang-".count))
        }
    }
    return ""
}

func extractRawText(from node: Node) -> String {
    var result = ""
    for child in node.getChildNodes() {
        if let textNode = child as? TextNode {
            result += textNode.getWholeText()
        } else if let element = child as? Element {
            let tag = element.tagName()
            if tag == "br" || tag == "div" {
                result += "\n"
            }
            result += extractRawText(from: element)
        }
    }
    return result
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

private func renderListContainer(node: Node, converter: Converter, isOrdered: Bool, marker: String, startAt: Int) throws -> String {
    guard let element = node as? Element else { return "" }

    var items: [String] = []
    for child in element.getChildNodes() {
        guard let liElement = child as? Element, liElement.tagName() == "li" else { continue }
        let content = try renderChildren(liElement, converter: converter)
        let trimmed = trimConsecutiveNewlines(content).trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            items.append(trimmed)
        }
    }

    if items.isEmpty { return "" }

    var result = "\n\n"
    for (i, item) in items.enumerated() {
        let prefix: String
        if isOrdered {
            prefix = "\(startAt + i). "
        } else {
            prefix = "\(marker) "
        }
        let indentCount = prefix.count
        let indent = String(repeating: " ", count: indentCount)

        let lines = item.components(separatedBy: "\n")
        let firstLine = "\(prefix)\(lines[0])"
        if lines.count > 1 {
            let rest = lines.dropFirst().map { line in
                line.isEmpty ? "" : "\(indent)\(line)"
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
