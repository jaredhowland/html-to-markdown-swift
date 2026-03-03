import Foundation
import SwiftSoup

extension CommonmarkPlugin {

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

    func handleDocumentPreRender(document: Document, converter: Converter) throws {
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
    private func moveListItems(_ doc: Document) throws {
        let listElements = try doc.select("ul, ol")
        for list in listElements {
            var changed = true
            while changed {
                changed = false
                let children = list.getChildNodes()
                for (idx, child) in children.enumerated() {
                    if let textNode = child as? TextNode {
                        if textNode.getWholeText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continue
                        }
                    }
                    if let element = child as? Element, element.tagName() == "li" {
                        continue
                    }
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
        if let sibling = node.nextSibling() { return sibling }
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
        if let child = node.getChildNodes().first { return child }
        if let sibling = node.nextSibling() { return sibling }
        var current: Node? = node.parent()
        while let parent = current {
            if let sibling = parent.nextSibling() { return sibling }
            current = parent.parent()
        }
        return nil
    }

    /// Checks if the next reachable neighbor after a list node is also a list.
    private func nextNameIsList(_ listNode: Node) -> Bool {
        var node: Node? = getNextNeighborNodeExcludingOwnChild(listNode)
        while let current = node {
            if let element = current as? Element {
                let tag = element.tagName()
                if tag == "ul" || tag == "ol" { return true }
                if tag == "li" { return false }
                if tag == "hr" { return false }
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
    func addListEndComments(_ doc: Document) throws {
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

    /// Get first non-span child that is inline code, skipping empty spans.
    private func getFirstCodeChild(_ node: Node) -> Node? {
        var child: Node? = (node as? Element)?.getChildNodes().first
        while let c = child {
            if let el = c as? Element {
                if el.tagName() == "span" {
                    if el.getChildNodes().isEmpty {
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

    /// Get last non-span child that is inline code, skipping empty spans.
    private func getLastCodeChild(_ node: Node) -> Node? {
        var child: Node? = (node as? Element)?.getChildNodes().last
        while let c = child {
            if let el = c as? Element {
                if el.tagName() == "span" {
                    if el.getChildNodes().isEmpty {
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

    /// Get previous adjacent text node.
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

    /// Get next adjacent text node.
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

    /// Generic adjacent element merger.
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
    private func nextMatchingSibling(
        _ element: Element,
        matchFn: (String) -> Bool,
        sameFamilyFn: (String) -> Bool
    ) -> Element? {
        var sibling: Node? = element.nextSibling()
        while let s = sibling {
            if s is TextNode {
                return nil
            }
            if let el = s as? Element {
                let tag = el.tagName()
                if tag == "span" {
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
}
