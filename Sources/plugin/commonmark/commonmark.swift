import Foundation
import SwiftSoup

/// Plugin implementing CommonMark Markdown specification
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

    func initialize(conv converter: Converter) {
        // Skip initialization if config validation already failed
        guard validationError == nil else { return }

        // Check that base plugin is registered (mirrors Go's base plugin check in Init())
        guard converter.plugins.contains(where: { $0.name == "base" }) else {
            validationError = ConversionError.pluginError(
                #"you registered the "commonmark" plugin but the "base" plugin is also required"#
            )
            return
        }

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
            throw err
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
