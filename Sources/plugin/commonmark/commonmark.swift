import Foundation
import SwiftSoup

class CommonmarkPlugin: Plugin {
    var name: String { return "commonmark" }
    let options: CommonmarkOptions
    var validationError: Error?

    init(options: CommonmarkOptions = CommonmarkOptions()) {
        self.options = options
        do {
            try validateCommonmarkOptions(options)
        } catch {
            self.validationError = error
        }
    }

    func initialize(conv: Converter) throws {
        if let err = validationError { throw err }

        guard conv.registeredPluginNames.contains("base") else {
            throw ConversionError.pluginError(
                #"you registered the "commonmark" plugin but the "base" plugin is also required"#
            )
        }

        // Escaped chars
        conv.Register.escapedChar(
            "\\", "*", "_", "-", "+", ".", ">", "|", "$", "#", "=",
            "[", "]", "(", ")", "!", "~", "`", "\"", "'"
        )

        // UnEscapers
        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, (chars[idx] == "*" || chars[idx] == "_") else { return -1 }
            return isEmphasisContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count else { return -1 }
            let ch = chars[idx]
            if ch == "-" || ch == "_" || ch == "*" {
                return isDividerContext(chars: chars, charIdx: idx) ? 1 : -1
            }
            return -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "#" else { return -1 }
            return isAtxHeaderContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "-" || chars[idx] == "=" else { return -1 }
            return isSetextHeaderContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count else { return -1 }
            let ch = chars[idx]
            guard ch == "-" || ch == "*" || ch == "+" else { return -1 }
            return isUnorderedListContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "." || chars[idx] == ")" else { return -1 }
            return isOrderedListContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "[" else { return -1 }
            return isOpenBracketContext(chars: chars, charIdx: idx) ? 1 : -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count else { return -1 }
            let ch = chars[idx]
            if ch == "`" { return !isSubsequentFencedBacktick(chars: chars, charIdx: idx) ? 1 : -1 }
            if ch == "~" { return isFencedCodeContext(chars: chars, charIdx: idx) ? 1 : -1 }
            return -1
        }, priority: PriorityStandard)

        conv.Register.unEscaper({ chars, idx in
            guard idx < chars.count, chars[idx] == "\\" else { return -1 }
            return 1
        }, priority: PriorityStandard)

        // Pre-render: DOM transforms (standard priority)
        conv.Register.preRenderer({ [weak self] ctx, doc in
            guard let self = self else { return }
            try? self.handleDocumentPreRender(document: doc, converter: ctx.conv)
        }, priority: PriorityStandard)

        // Pre-render: list end comments (very late, after whitespace collapse)
        if !options.disableListEndComment {
            conv.Register.preRenderer({ [weak self] ctx, doc in
                guard let self = self else { return }
                try? self.addListEndComments(doc)
            }, priority: PriorityLate + 100)
        }

        // Register all element renderers
        registerBoldItalicRenderers(conv: conv)
        registerLinkRenderers(conv: conv)
        registerImageRenderers(conv: conv)
        registerCodeRenderers(conv: conv)
        registerBlockquoteRenderer(conv: conv)
        registerListRenderers(conv: conv)
        registerHeadingRenderers(conv: conv)
        registerDividerRenderer(conv: conv)
        registerBreakRenderer(conv: conv)
        registerCommentRenderer(conv: conv)
    }

    // MARK: - Tag check helpers
    func isBoldTag(_ tag: String) -> Bool { tag == "b" || tag == "strong" }
    func isItalicTag(_ tag: String) -> Bool { tag == "em" || tag == "i" }
    func isInlineCodeTag(_ tag: String) -> Bool {
        tag == "code" || tag == "var" || tag == "samp" || tag == "kbd" || tag == "tt"
    }

    func hasTextContent(_ node: Node) -> Bool {
        for child in node.getChildNodes() {
            if let textNode = child as? TextNode {
                if !textNode.getWholeText().isEmpty { return true }
            } else if let element = child as? Element {
                if hasTextContent(element) { return true }
            }
        }
        return false
    }
}
