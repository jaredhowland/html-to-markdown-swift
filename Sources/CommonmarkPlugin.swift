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
    /// When true, suppresses the `<!--THE END-->` comment inserted between consecutive lists
    public var disableListEndComment: Bool = false

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

    func handleDocumentPreRender(document: Document, converter: Converter) throws {
        if let err = validationError {
            throw ConversionError.pluginError("error while initializing \"commonmark\" plugin: \(err.localizedDescription)")
        }
        try removeEmptyCode(document)
        try removeRedundantBoldItalic(document)
        try mergeAdjacentBoldItalic(document)
        try mergeAdjacentInlineCode(document)
    }

    // MARK: - DOM Pre-render Transformations

    private func isBoldTag(_ tag: String) -> Bool { tag == "b" || tag == "strong" }
    private func isItalicTag(_ tag: String) -> Bool { tag == "em" || tag == "i" }
    private func isInlineCodeTag(_ tag: String) -> Bool {
        tag == "code" || tag == "var" || tag == "samp" || tag == "kbd" || tag == "tt"
    }

    private func hasTextContent(_ node: Node) -> Bool {
        for child in node.getChildNodes() {
            if let textNode = child as? TextNode {
                if !textNode.getWholeText().isEmpty { return true }
            } else if let element = child as? Element {
                if hasTextContent(element) { return true }
            }
        }
        return false
    }

    /// Remove <code> elements that have no text content (matches Go's RemoveEmptyCode)
    private func removeEmptyCode(_ doc: Document) throws {
        let codeElements = try doc.select("code")
        var toRemove: [Element] = []
        for element in codeElements {
            if !hasTextContent(element) {
                toRemove.append(element)
            }
        }
        for element in toRemove {
            try element.remove()
        }
    }

    /// Unwrap redundant nested bold/italic elements (matches Go's RemoveRedundant)
    private func removeRedundantBoldItalic(_ doc: Document) throws {
        var toUnwrap: [Element] = []
        for element in try doc.select("b, strong") {
            if hasBoldAncestor(element) { toUnwrap.append(element) }
        }
        for element in toUnwrap { try element.unwrap() }

        toUnwrap = []
        for element in try doc.select("em, i") {
            if hasItalicAncestor(element) { toUnwrap.append(element) }
        }
        for element in toUnwrap { try element.unwrap() }
    }

    private func hasBoldAncestor(_ element: Element) -> Bool {
        var parent = element.parent()
        while let p = parent {
            if isBoldTag(p.tagName()) { return true }
            parent = p.parent()
        }
        return false
    }

    private func hasItalicAncestor(_ element: Element) -> Bool {
        var parent = element.parent()
        while let p = parent {
            if isItalicTag(p.tagName()) { return true }
            parent = p.parent()
        }
        return false
    }

    /// Merge adjacent bold/italic elements (matches Go's MergeAdjacent for bold/italic)
    private func mergeAdjacentBoldItalic(_ doc: Document) throws {
        try mergeAdjacentElements(doc, matchFn: { tag in
            self.isBoldTag(tag) || self.isItalicTag(tag)
        }, sameFamilyFn: { a, b in
            let aB = self.isBoldTag(a), bB = self.isBoldTag(b)
            let aI = self.isItalicTag(a), bI = self.isItalicTag(b)
            return (aB && bB) || (aI && bI)
        })
    }

    /// Merge adjacent inline code elements (matches Go's MergeAdjacent for inline code)
    private func mergeAdjacentInlineCode(_ doc: Document) throws {
        try mergeAdjacentElements(doc, matchFn: { self.isInlineCodeTag($0) },
                                   sameFamilyFn: { _, _ in true })
    }

    /// Generic adjacent element merger: for each matching element, if the next sibling
    /// (skipping whitespace-only text nodes and spans) is also in the same family, merge.
    private func mergeAdjacentElements(
        _ doc: Document,
        matchFn: (String) -> Bool,
        sameFamilyFn: (String, String) -> Bool
    ) throws {
        var changed = true
        while changed {
            changed = false
            let allElements = try doc.getAllElements()
            for element in allElements {
                let tag = element.tagName()
                guard matchFn(tag) else { continue }
                guard let nextEl = nextMatchingSibling(element, matchFn: matchFn,
                                                       sameFamilyFn: { sameFamilyFn(tag, $0) })
                else { continue }

                // Move all children of nextEl into element, then remove nextEl
                let children = nextEl.getChildNodes()
                for child in children {
                    try child.remove()
                    try element.appendChild(child)
                }
                try nextEl.remove()
                changed = true
                break
            }
        }
    }

    /// Find the next sibling element that is in the same family, skipping spans and
    /// whitespace-only text nodes. Returns nil if a non-matching, non-skippable node is found first.
    private func nextMatchingSibling(
        _ element: Element,
        matchFn: (String) -> Bool,
        sameFamilyFn: (String) -> Bool
    ) -> Element? {
        var sibling: Node? = element.nextSibling()
        while let s = sibling {
            if let textNode = s as? TextNode {
                if textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sibling = s.nextSibling()
                    continue
                }
                return nil  // non-empty text between → stop
            }
            if let el = s as? Element {
                let tag = el.tagName()
                if tag == "span" {
                    // DFS into span: if its first child is a TextNode (any), stop merge;
                    // if nil, skip span; if Element, dive into it (matches Go's GetNextNeighborNode).
                    if let firstChild = el.getChildNodes().first {
                        if firstChild is TextNode { return nil }
                        if let childEl = firstChild as? Element {
                            sibling = childEl
                            continue
                        }
                    }
                    sibling = s.nextSibling()
                    continue
                }
                if matchFn(tag) && sameFamilyFn(tag) { return el }
                return nil
            }
            return nil
        }
        return nil
    }

    // MARK: - Bold and Italic Rendering

    private func registerBoldItalicRenderers(converter: Converter) {
        for tag in ["strong", "b"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                guard let self = self else { return nil }
                let delimiter = self.options.strongDelimiter
                if let result = try self.renderEmphasisWrappingLink(node, delimiter: delimiter, converter: converter) {
                    return result
                }
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
        for tag in ["em", "i"] {
            converter.registerRenderer(tag) { [weak self] node, converter in
                guard let self = self else { return nil }
                let delimiter = self.options.emDelimiter
                if let result = try self.renderEmphasisWrappingLink(node, delimiter: delimiter, converter: converter) {
                    return result
                }
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: delimiter)
            }
        }
    }

    /// SwapTags(bold/italic, link): if the sole non-whitespace child is an `<a>`, render as
    /// `[**content**](href)` instead of `**[content](href)**`.
    private func renderEmphasisWrappingLink(_ node: Node, delimiter: String, converter: Converter) throws -> String? {
        guard let element = node as? Element else { return nil }

        let nonWsChildren = element.getChildNodes().filter { child in
            if let text = child as? TextNode {
                return !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }

        guard nonWsChildren.count == 1,
              let linkEl = nonWsChildren[0] as? Element,
              linkEl.tagName() == "a" else { return nil }

        let rawHref = (try? linkEl.attr("href")) ?? ""
        let href = assembleAbsoluteURL(rawHref, domain: converter.getOptions().baseDomain)

        if href.isEmpty && options.linkEmptyHrefBehavior == .skip {
            let content = try renderChildren(node, converter: converter)
            return applyDelimiterPerLine(content, delimiter: delimiter)
        }

        let rawTitle = (try? linkEl.attr("title")) ?? ""
        let title = rawTitle
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")

        let linkContent = try renderChildren(linkEl, converter: converter)
        let linkContentEscaped = linkContent.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")
        let trimmedContent = linkContentEscaped.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedContent.isEmpty && options.linkEmptyContentBehavior == .skip {
            return ""
        }

        let boldContent = applyDelimiterPerLine(linkContentEscaped, delimiter: delimiter)
        let trimmedBold = boldContent.trimmingCharacters(in: .whitespacesAndNewlines)

        let leftPad = String(linkContentEscaped.prefix(while: { $0.isWhitespace }))
        let rightPad = String(linkContentEscaped.reversed().prefix(while: { $0.isWhitespace }).reversed())

        if title.isEmpty {
            return "\(leftPad)[\(trimmedBold)](\(href))\(rightPad)"
        } else {
            return "\(leftPad)[\(trimmedBold)](\(href) \(formatLinkTitle(title)))\(rightPad)"
        }
    }

    // MARK: - Link Rendering

    private func formatLinkTitle(_ title: String) -> String {
        // Collapse newlines to space (matches Go: strings.ReplaceAll(title, "\n", " "))
        let normalized = title
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let hasDouble = normalized.contains("\"")
        let hasSingle = normalized.contains("'")
        if hasDouble && hasSingle {
            let escaped = normalized.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        if hasDouble {
            return "'\(normalized)'"
        }
        return "\"\(normalized)\""
    }

    /// Assemble an absolute URL from a raw href and optional base domain.
    /// Matches Go's defaultAssembleAbsoluteURL logic.
    private func assembleAbsoluteURL(_ rawURL: String, domain: String?) -> String {
        var url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Go special-cases "#" to avoid fragment confusion in url.Parse
        if url == "#" { return url }

        // Encode control characters (Go: ReplaceAll "\n"→"%0A", "\t"→"%09")
        url = url.replacingOccurrences(of: "\n", with: "%0A")
        url = url.replacingOccurrences(of: "\t", with: "%09")

        // Resolve against base domain if provided
        if let domain = domain, !domain.isEmpty {
            if let baseURL = parseBaseDomain(domain) {
                let urlForParsing = url.replacingOccurrences(of: " ", with: "%20")
                if let relURL = URL(string: urlForParsing, relativeTo: baseURL) {
                    url = relURL.absoluteString
                } else if !url.hasPrefix("http") && !url.contains(":") {
                    let base = domain.hasSuffix("/") ? String(domain.dropLast()) : domain
                    let path = url.hasPrefix("/") ? url : "/" + url
                    url = base + path
                }
            }
        }

        // Apply final percent encoding (matches Go's percentEncodingReplacer)
        url = url.replacingOccurrences(of: " ", with: "%20")
        url = url.replacingOccurrences(of: "[", with: "%5B")
        url = url.replacingOccurrences(of: "]", with: "%5D")
        url = url.replacingOccurrences(of: "(", with: "%28")
        url = url.replacingOccurrences(of: ")", with: "%29")
        url = url.replacingOccurrences(of: "<", with: "%3C")
        url = url.replacingOccurrences(of: ">", with: "%3E")
        return url
    }

    private func parseBaseDomain(_ rawDomain: String) -> URL? {
        if rawDomain.isEmpty { return nil }
        if let url = URL(string: rawDomain), url.host != nil { return url }
        if let url = URL(string: "http://" + rawDomain), url.host != nil { return url }
        return nil
    }

    private func registerLinkRenderers(converter: Converter) {
        converter.registerRenderer("a") { [weak self] node, converter in
            guard let element = node as? Element else { return nil }
            guard let self = self else { return nil }

            let rawHref = (try? element.attr("href")) ?? ""
            let href = self.assembleAbsoluteURL(rawHref, domain: converter.getOptions().baseDomain)

            if href.isEmpty && self.options.linkEmptyHrefBehavior == .skip {
                return try renderChildren(node, converter: converter)
            }

            // Go replaces "\n" with " " in title but does NOT trim surrounding whitespace
            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            // SwapTags(link, heading): if sole non-whitespace child is a heading,
            // render as heading containing the link: `## [content](href)`
            let nonWsChildren = element.getChildNodes().filter { child in
                if let text = child as? TextNode {
                    return !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
                return true
            }
            if nonWsChildren.count == 1, let headingEl = nonWsChildren[0] as? Element {
                let tagName = headingEl.tagName()
                if tagName.count == 2 && tagName.first == "h",
                   let level = Int(String(tagName.last!)), (1...6).contains(level) {
                    let hContent = try renderChildren(headingEl, converter: converter)
                    let hContentEscaped = hContent.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")
                    let trimmedH = hContentEscaped.trimmingCharacters(in: .whitespacesAndNewlines)
                    let linkMd = title.isEmpty
                        ? "[\(trimmedH)](\(href))"
                        : "[\(trimmedH)](\(href) \(self.formatLinkTitle(title)))"
                    if self.options.headingStyle == .setext && level <= 2 {
                        let underlineChar: Character = level == 1 ? "=" : "-"
                        let underline = String(repeating: underlineChar, count: max(3, trimmedH.count))
                        return "\n\n\(linkMd)\n\(underline)\n\n"
                    } else {
                        let hashes = String(repeating: "#", count: level)
                        return "\n\n\(hashes) \(linkMd)\n\n"
                    }
                }
            }

            let content = try renderChildren(node, converter: converter)
            // Force-escape ] inside link text to prevent premature link closing
            let contentEscaped = content.replacingOccurrences(of: "\(escapePlaceholder)]", with: "\\]")

            // Extract surrounding whitespace (matches Go's SurroundingSpaces)
            let leftPad = String(contentEscaped.prefix(while: { $0.isWhitespace }))
            let withoutLeft = String(contentEscaped.drop(while: { $0.isWhitespace }))
            let rightPad = String(withoutLeft.reversed().prefix(while: { $0.isWhitespace }).reversed())
            var innerContent = String(withoutLeft.dropLast(rightPad.count))

            if innerContent.isEmpty && self.options.linkEmptyContentBehavior == .skip {
                return ""
            }

            innerContent = trimConsecutiveNewlines(innerContent)
            innerContent = escapeMultiLine(innerContent)

            if title.isEmpty {
                return "\(leftPad)[\(innerContent)](\(href))\(rightPad)"
            } else {
                return "\(leftPad)[\(innerContent)](\(href) \(self.formatLinkTitle(title)))\(rightPad)"
            }
        }
    }

    // MARK: - Image Rendering

    private func registerImageRenderers(converter: Converter) {
        converter.registerRenderer("img") { [weak self] node, converter in
            guard let element = node as? Element else { return nil }
            guard let self = self else { return nil }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = self.assembleAbsoluteURL(rawSrc, domain: converter.getOptions().baseDomain)
            if src.isEmpty { return "" }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let alt = escapeAltText(rawAlt)

            // Go replaces "\n" with " " in title but does NOT trim surrounding whitespace
            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            if title.isEmpty {
                return "![\(alt)](\(src))"
            } else {
                return "![\(alt)](\(src) \(self.formatLinkTitle(title)))"
            }
        }
    }

    // MARK: - Code Rendering

    private func registerCodeRenderers(converter: Converter) {
        let inlineCodeRenderer: NodeRenderer = { node, converter in
            if let element = node as? Element, let parent = element.parent(), parent.tagName() == "pre" {
                return extractRawText(from: element)
            }

            guard let element = node as? Element else { return nil }
            let fenceChar: Character = "`"

            // Extract raw text without HTML-escaping (code content preserves < > as-is)
            let rawContent = extractRawText(from: element)

            // Spaces-only content: preserve without stripping
            if rawContent.trimmingCharacters(in: .whitespaces).isEmpty {
                return "`\(rawContent)`"
            }

            // Collapse whitespace: newlines/tabs→space, trim, deduplicate spaces
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
            if trimmed.isEmpty { return "" }
            trimmed = trimConsecutiveNewlines(trimmed)
            trimmed = trimUnnecessaryHardLineBreaks(trimmed)
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
            var result = try renderListContainer(node: node, converter: converter, isOrdered: false, marker: marker, startAt: 1)
            if !self.options.disableListEndComment, let element = node as? Element {
                let nextTag = try? element.nextElementSibling()?.tagName()
                if nextTag == "ul" || nextTag == "ol" {
                    result = result.replacingOccurrences(of: "\n+$", with: "", options: .regularExpression)
                    result += "\n\n<!--THE END-->"
                }
            }
            return result
        }

        converter.registerRenderer("ol") { [weak self] node, converter in
            guard let self = self else { return nil }
            var startAt = 1
            if let element = node as? Element,
               let startStr = try? element.attr("start"),
               let start = Int(startStr) {
                startAt = start
            }
            var result = try renderListContainer(node: node, converter: converter, isOrdered: true, marker: "-", startAt: startAt)
            if !self.options.disableListEndComment, let element = node as? Element {
                let nextTag = try? element.nextElementSibling()?.tagName()
                if nextTag == "ul" || nextTag == "ol" {
                    result = result.replacingOccurrences(of: "\n+$", with: "", options: .regularExpression)
                    result += "\n\n<!--THE END-->"
                }
            }
            return result
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
                    let escaped = escapeMultiLine(trimmed)
                    let lines = escaped.components(separatedBy: "\n")
                    let maxWidth = max(3, lines.map { $0.count }.max() ?? 3)
                    let underlineChar: Character = level == 1 ? "=" : "-"
                    let underline = String(repeating: underlineChar, count: maxWidth)
                    return "\n\n\(escaped)\n\(underline)\n\n"
                } else {
                    let flat = trimmed
                        .replacingOccurrences(of: "\n", with: " ")
                        .replacingOccurrences(of: "\r", with: " ")
                    let collapsed = escapePoundSignAtEnd(collapseWhitespace(flat))
                    let hashes = String(repeating: "#", count: level)
                    return "\n\n\(hashes) \(collapsed)\n\n"
                }
            }
        }
    }

    private func escapePoundSignAtEnd(_ s: String) -> String {
        guard !s.isEmpty, s.last == "#" else { return s }
        if s.count >= 2 {
            let beforeLast = s.index(s.endIndex, offsetBy: -2)
            if s[beforeLast] == "\\" { return s }
        }
        return String(s.dropLast()) + "\\#"
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

/// Collapse whitespace inside inline code content (matches Go's CollapseInlineCodeContent).
/// Replaces newlines and tabs with spaces, trims, then collapses multiple spaces to one.
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

/// Escape [ and ] characters in image alt text (matches Go's escapeAlt function)
private func escapeAltText(_ alt: String) -> String {
    var result = ""
    let chars = Array(alt)
    for (i, ch) in chars.enumerated() {
        if ch == "[" || ch == "]" {
            let prevIndex = i - 1
            if prevIndex < 0 || chars[prevIndex] != "\\" {
                result.append("\\")
            }
        }
        result.append(ch)
    }
    return result
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
        let firstLine = "\(prefix)\(lines[0])"
        if lines.count > 1 {
            let rest = lines.dropFirst().map { line in
                line.isEmpty ? indent : "\(indent)\(line)"
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
