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
        try renameFakeSpans(document)
        try removeEmptyCode(document)
        try removeRedundantBoldItalic(document)
        try mergeAdjacentBoldItalic(document)
        try swapTagsCodePre(document)
        try mergeAdjacentInlineCode(document)
        try addSpacesAroundEmphasisContainingCode(document)
        try removeRedundantLink(document)
        try swapTagsLinkHeading(document)
        try leafBlockAlternatives(document)
        try moveListItems(document)
        if !options.disableListEndComment {
            try addListEndComments(document)
        }
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

    private static let blockNodeNames: Set<String> = [
        "address", "article", "aside", "audio", "blockquote", "body", "canvas", "center",
        "dd", "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure", "footer",
        "form", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup",
        "hr", "html", "isindex", "li", "main", "menu", "nav", "noframes", "noscript",
        "ol", "output", "p", "pre", "section", "table", "tbody", "td", "tfoot", "th",
        "thead", "tr", "ul"
    ]

    private func isBlockNode(_ tag: String) -> Bool {
        CommonmarkPlugin.blockNodeNames.contains(tag)
    }

    /// Matches Go's RemoveRedundant(doc, nameIsBothLink): unwrap any <a> that has
    /// an ancestor <a>, since nested links are invalid in markdown.
    private func removeRedundantLink(_ doc: Document) throws {
        let links = try doc.select("a")
        for link in links {
            var p = link.parent()
            while let parent = p {
                if let parentEl = parent as? Element, parentEl.tagName() == "a" {
                    try link.unwrap()
                    break
                }
                p = parent.parent()
            }
        }
    }

    /// Matches Go's domutils.RenameFakeSpans: renames <span> to <div> if
    /// any block element is found as a descendant.
    private func renameFakeSpans(_ doc: Document) throws {
        func containsBlock(_ node: Node) -> Bool {
            for child in node.getChildNodes() {
                if let el = child as? Element {
                    if isBlockNode(el.tagName()) { return true }
                    if containsBlock(el) { return true }
                }
            }
            return false
        }
        func walk(_ node: Node) throws {
            if let el = node as? Element, el.tagName() == "span", containsBlock(el) {
                try el.tagName("div")
            }
            for child in node.getChildNodes() {
                try walk(child)
            }
        }
        try walk(doc)
    }

    /// Matches Go's SwapTags(nameIsLink, nameIsHeading): if an <a> element has a sole
    /// non-whitespace child that is a heading, swap their tag names and attributes.
    private func swapTagsLinkHeading(_ doc: Document) throws {
        let headingTags: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
        func walk(_ node: Node) throws {
            if let link = node as? Element, link.tagName() == "a" {
                let nonWs = link.getChildNodes().filter { child in
                    if let text = child as? TextNode {
                        return !text.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    return true
                }
                if nonWs.count == 1, let inner = nonWs[0] as? Element, headingTags.contains(inner.tagName()) {
                    // Swap tag names and attributes (matching Go's swapTagsOfNodes)
                    let outerTag = link.tagName()
                    let innerTag = inner.tagName()
                    let outerAttrs = link.getAttributes()?.asList() ?? []
                    let innerAttrs = inner.getAttributes()?.asList() ?? []
                    try link.tagName(innerTag)
                    try inner.tagName(outerTag)
                    for attr in outerAttrs { try link.removeAttr(attr.getKey()) }
                    for attr in innerAttrs { try link.attr(attr.getKey(), attr.getValue()) }
                    for attr in innerAttrs { try inner.removeAttr(attr.getKey()) }
                    for attr in outerAttrs { try inner.attr(attr.getKey(), attr.getValue()) }
                    return
                }
            }
            for child in node.getChildNodes() {
                try walk(child)
            }
        }
        try walk(doc)
    }

    /// SwapTags(code, pre): if a code/var/samp/kbd/tt element's sole non-whitespace-text
    /// child is a <pre>, swap their tag names so <code><pre>x</pre></code> becomes
    /// <pre><code>x</code></pre>, which then renders as a fenced code block.
    /// Matches Go's domutils.SwapTags(ctx, doc, nameIsInlineCode, nameIsPre).
    private func swapTagsCodePre(_ doc: Document) throws {
        let inlineCodeTags = ["code", "var", "samp", "kbd", "tt"]
        func swapIn(_ node: Node) throws {
            if let element = node as? Element, inlineCodeTags.contains(element.tagName()) {
                let nonEmptyChildren = element.getChildNodes().filter { child in
                    if let text = child as? TextNode {
                        return !text.getWholeText().trimmingCharacters(in: .whitespaces).isEmpty
                    }
                    return true
                }
                if nonEmptyChildren.count == 1,
                   let inner = nonEmptyChildren[0] as? Element,
                   inner.tagName() == "pre" {
                    // Swap tag names AND attributes (matching Go's swapTagsOfNodes)
                    let outerTag = element.tagName()
                    let innerTag = inner.tagName()
                    let outerAttrs = element.getAttributes()?.asList() ?? []
                    let innerAttrs = inner.getAttributes()?.asList() ?? []
                    try element.tagName(innerTag)
                    try inner.tagName(outerTag)
                    for attr in outerAttrs { try element.removeAttr(attr.getKey()) }
                    for attr in innerAttrs { try element.attr(attr.getKey(), attr.getValue()) }
                    for attr in innerAttrs { try inner.removeAttr(attr.getKey()) }
                    for attr in outerAttrs { try inner.attr(attr.getKey(), attr.getValue()) }
                    // Go's HTML5 parser strips the leading LF from <pre> start tag during
                    // parsing (HTML5 spec). After swapping, the inner element (was <pre>)
                    // would have had its leading \n stripped. We replicate that here.
                    if let firstText = inner.getChildNodes().first as? TextNode {
                        let t = firstText.getWholeText()
                        if t.hasPrefix("\n") {
                            try firstText.text(String(t.dropFirst()))
                        }
                    }
                    return
                }
            }
            for child in node.getChildNodes() {
                try swapIn(child)
            }
        }
        try swapIn(doc)
    }

    /// Matches Go's domutils.LeafBlockAlternatives.
    /// When a block element appears inside a leaf-block or inline context, replace it
    /// with a markdown-compatible alternative.
    private func leafBlockAlternatives(_ doc: Document) throws {
        func getMarkdownStructure(_ tag: String) -> String {
            switch tag {
            case "#document", "html", "head", "body",
                 "blockquote", "ul", "ol", "li":
                return "container_block"
            case "hr", "pre", "h1", "h2", "h3", "h4", "h5", "h6":
                return "leaf_block"
            case "#text", "span", "code",
                 "b", "strong", "i", "em",
                 "a", "img", "br":
                return "inline"
            default:
                return ""
            }
        }

        func process(_ node: Node, isInsideLeafBlock: Bool, isInsideInline: Bool) throws {
            var newIsLeaf = isInsideLeafBlock
            var newIsInline = isInsideInline

            if let element = node as? Element {
                let tag = element.tagName()
                let structure = getMarkdownStructure(tag)

                if (structure == "container_block" || structure == "leaf_block") && (isInsideLeafBlock || isInsideInline) {
                    switch tag {
                    case "h1", "h2", "h3", "h4", "h5", "h6":
                        try element.tagName("strong")
                        // Insert <br> after this node
                        let br = Element(Tag("br"), "")
                        try element.after(br)
                    case "blockquote":
                        let quoteBefore = TextNode(" \"", "")
                        let quoteAfter = TextNode("\" ", "")
                        try element.before(quoteBefore)
                        try element.after(quoteAfter)
                        try element.tagName("span")
                    case "pre":
                        try element.tagName("code")
                    case "hr":
                        try element.remove()
                        return
                    default:
                        try element.tagName("span")
                    }
                }

                if structure == "leaf_block" { newIsLeaf = true }
                if structure == "inline" { newIsInline = true }
            }

            let children = node.getChildNodes()
            for child in children {
                try process(child, isInsideLeafBlock: newIsLeaf, isInsideInline: newIsInline)
            }
        }

        try process(doc, isInsideLeafBlock: false, isInsideInline: false)
    }

    /// Matches Go's domutils.MoveListItems.
    /// In <ol>/<ul>, non-<li> non-whitespace children are moved into the previous <li>
    /// or wrapped in a new <li>.
    private func moveListItems(_ doc: Document) throws {
        let listElements = try doc.select("ul, ol")
        for list in listElements {
            var changed = true
            while changed {
                changed = false
                let children = list.getChildNodes()
                for (idx, child) in children.enumerated() {
                    // Skip whitespace-only text nodes
                    if let textNode = child as? TextNode {
                        if textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continue
                        }
                    }
                    // Skip <li> elements — they're fine
                    if let element = child as? Element, element.tagName() == "li" {
                        continue
                    }
                    // Non-li node: find previous <li>
                    var prevLi: Element? = nil
                    for prevIdx in (0..<idx).reversed() {
                        if let el = children[prevIdx] as? Element, el.tagName() == "li" {
                            prevLi = el
                            break
                        }
                    }
                    try child.remove()
                    if let li = prevLi {
                        try li.appendChild(child)
                    } else {
                        // No previous li: wrap in new <li>
                        let newLi = Element(Tag("li"), "")
                        try newLi.appendChild(child)
                        try list.prependChild(newLi)
                    }
                    changed = true
                    break
                }
            }
        }
    }

    // MARK: - List End Comments

    /// Returns the next neighbor node excluding own children.
    /// Matches Go's dom.GetNextNeighborNodeExcludingOwnChild.
    private func getNextNeighborNodeExcludingOwnChild(_ node: Node) -> Node? {
        // Skip own children: try next sibling first
        if let sibling = node.nextSibling() { return sibling }
        // Walk up the tree to find a parent with a next sibling
        var current: Node? = node.parent()
        while let parent = current {
            if let sibling = parent.nextSibling() { return sibling }
            current = parent.parent()
        }
        return nil
    }

    /// Returns the next neighbor node (including own children first).
    /// Matches Go's dom.GetNextNeighborNode.
    private func getNextNeighborNode(_ node: Node) -> Node? {
        // Try first child
        if let child = node.getChildNodes().first { return child }
        // Then next sibling
        if let sibling = node.nextSibling() { return sibling }
        // Walk up the tree
        var current: Node? = node.parent()
        while let parent = current {
            if let sibling = parent.nextSibling() { return sibling }
            current = parent.parent()
        }
        return nil
    }

    /// Checks if the next reachable neighbor after a list node is also a list.
    /// Whitespace-only text nodes are skipped (they would be removed by whitespace collapse).
    /// Matches Go's nextNameIsList in domutils/list_end_comment.go.
    private func nextNameIsList(_ listNode: Node) -> Bool {
        var node: Node? = getNextNeighborNodeExcludingOwnChild(listNode)
        while let current = node {
            if let element = current as? Element {
                let tag = element.tagName()
                if tag == "ul" || tag == "ol" { return true }
                if tag == "li" { return false }
                if tag == "hr" { return false }
                // For other elements, continue traversal into their children
                node = getNextNeighborNode(current)
                continue
            }
            if let comment = current as? Comment {
                if comment.getData() == "THE END" { return false }
                node = getNextNeighborNode(current)
                continue
            }
            if let textNode = current as? TextNode {
                let text = textNode.getWholeText()
                // Whitespace-only text nodes are removed by collapse, so skip them
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    node = getNextNeighborNode(current)
                    continue
                }
                return false
            }
            node = getNextNeighborNode(current)
        }
        return false
    }

    /// Inserts `<!--THE END-->` comment nodes between adjacent lists in the DOM.
    /// Matches Go's domutils.AddListEndComments. Runs AFTER whitespace collapse logic is factored in
    /// by treating whitespace-only text nodes as transparent (equivalent to collapse removing them).
    private func addListEndComments(_ doc: Document) throws {
        let allElements = try doc.getAllElements()
        for element in allElements {
            let tag = element.tagName()
            guard tag == "ul" || tag == "ol" else { continue }
            if nextNameIsList(element) {
                try element.after("<!--THE END-->")
            }
        }
    }

    /// Mirrors Go's domutils.AddSpace(ctx, doc, nameIsBoldOrItalic, nameIsInlineCode).
    private func addSpacesAroundEmphasisContainingCode(_ doc: Document) throws {
        let emphasisElements = try doc.select("strong, b, em, i")
        for element in emphasisElements {
            if getFirstCodeChild(element) != nil {
                if let prevText = getPrevTextNodeOf(element) {
                    try prevText.text(prevText.getWholeText() + " ")
                }
            }
            if getLastCodeChild(element) != nil {
                if let nextText = getNextTextNodeOf(element) {
                    try nextText.text(" " + nextText.getWholeText())
                }
            }
        }
    }

    /// Get first non-span child that is inline code, skipping empty spans (matches Go's getFirstChildNode).
    private func getFirstCodeChild(_ node: Node) -> Node? {
        var child: Node? = (node as? Element)?.getChildNodes().first
        while let c = child {
            if let el = c as? Element {
                if el.tagName() == "span" {
                    if el.getChildNodes().isEmpty {
                        // Empty span: skip to next sibling (matches Go's GetNextNeighborNode)
                        child = el.nextSibling()
                    } else {
                        child = el.getChildNodes().first
                    }
                    continue
                }
                if isInlineCodeTag(el.tagName()) { return el }
            }
            return nil
        }
        return nil
    }

    /// Get last non-span child that is inline code, skipping empty spans (matches Go's getLastChildNode).
    private func getLastCodeChild(_ node: Node) -> Node? {
        var child: Node? = (node as? Element)?.getChildNodes().last
        while let c = child {
            if let el = c as? Element {
                if el.tagName() == "span" {
                    if el.getChildNodes().isEmpty {
                        // Empty span: skip to previous sibling (matches Go's GetPrevNeighborNode)
                        child = el.previousSibling()
                    } else {
                        child = el.getChildNodes().last
                    }
                    continue
                }
                if isInlineCodeTag(el.tagName()) { return el }
            }
            return nil
        }
        return nil
    }

    /// Get previous adjacent text node (matches Go's getPrevTextNode / GetPrevNeighborNodeExcludingOwnChild).
    private func getPrevTextNodeOf(_ node: Node) -> TextNode? {
        var prev: Node? = node.previousSibling()
        while let p = prev {
            if let textNode = p as? TextNode { return textNode }
            if let el = p as? Element, el.tagName() == "span" {
                prev = el.getChildNodes().last
                continue
            }
            return nil
        }
        return nil
    }

    /// Get next adjacent text node (matches Go's getNextTextNode / GetNextNeighborNodeExcludingOwnChild).
    private func getNextTextNodeOf(_ node: Node) -> TextNode? {
        var next: Node? = node.nextSibling()
        while let n = next {
            if let textNode = n as? TextNode { return textNode }
            if let el = n as? Element, el.tagName() == "span" {
                next = el.getChildNodes().first
                continue
            }
            return nil
        }
        return nil
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

    /// Returns nil if a non-matching, non-skippable node is found first.
    /// Mirrors Go's collectAdjacentNodes which stops immediately on any text node.
    private func nextMatchingSibling(
        _ element: Element,
        matchFn: (String) -> Bool,
        sameFamilyFn: (String) -> Bool
    ) -> Element? {
        var sibling: Node? = element.nextSibling()
        while let s = sibling {
            if s is TextNode {
                return nil  // any text node stops the merge (matches Go's collectAdjacentNodes)
            }
            if let el = s as? Element {
                let tag = el.tagName()
                if tag == "span" {
                    // DFS into span: if its first child is a TextNode, stop merge;
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

            // Go: when href is empty, title is invalid/dropped
            var effectiveTitle = title
            if href.isEmpty { effectiveTitle = "" }

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

            if effectiveTitle.isEmpty {
                return "\(leftPad)[\(innerContent)](\(href))\(rightPad)"
            } else {
                return "\(leftPad)[\(innerContent)](\(href) \(self.formatLinkTitle(effectiveTitle)))\(rightPad)"
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
            var hasCodeChild = false

            if let element = node as? Element {
                if let codeEl = try? element.select("code").first() {
                    hasCodeChild = true
                    // Go's getCodeWithoutTags visits <pre> first, then <code> children.
                    // So <pre>'s language class takes priority over <code>'s.
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
            // HTML5 spec: a single leading newline after <pre> start tag is stripped.
            // Go's HTML parser applies this only when text is directly inside <pre>,
            // not when it's inside a nested <code> element.
            if !hasCodeChild && rawContent.hasPrefix("\n") {
                rawContent = String(rawContent.dropFirst())
            }

            let maxRun = calculateMaxBacktickRun(in: rawContent, char: fenceChar)
            let fenceLen = max(3, maxRun + 1)
            let actualFence = String(repeating: fenceChar, count: fenceLen)

            // Replace \n inside code block with marker to protect from trimConsecutiveNewlines.
            // Matches Go's use of marker.MarkerCodeBlockNewline.
            let markedContent = rawContent.replacingOccurrences(of: "\n", with: String(codeBlockNewlineMarker))

            return "\n\n\(actualFence)\(language)\n\(markedContent)\n\(actualFence)\n\n"
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

    /// Matches Go's escapePoundSignAtEnd: if the heading content ends with #,
    /// force-escape it by replacing the placeholder before # with \\.
    /// If already escaped (\ before the placeholder), do nothing.
    private func escapePoundSignAtEnd(_ s: String) -> String {
        let chars = Array(s)
        let n = chars.count
        guard n >= 1, chars[n - 1] == "#" else { return s }
        // Structure: ... placeholder # (placeholder at n-2)
        // Check if already escaped: \ at n-3
        if n >= 3 && chars[n - 3] == "\\" {
            return s // Already escaped
        }
        // Overwrite the placeholder at n-2 with \
        if n >= 2 && chars[n - 2] == escapePlaceholder {
            var result = chars
            result[n - 2] = "\\"
            return String(result)
        }
        // No placeholder before #: just append escape
        return s.dropLast() + "\\#"
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
        converter.registerRenderer("#comment") { node, _ in
            // Render THE END list separator comments (inserted by addListEndComments)
            if let comment = node as? Comment, comment.getData() == "THE END" {
                return "\n\n<!--THE END-->\n\n"
            }
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
