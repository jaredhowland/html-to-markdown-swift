import Foundation
import SwiftSoup

/// Plugin implementing CommonMark Markdown specification
class CommonmarkPlugin: Plugin {
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

    // MARK: - Tag check helpers (internal: used from extension files)

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
