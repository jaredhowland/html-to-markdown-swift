import Foundation
import SwiftSoup

/// Plugin for strikethrough text support (~~text~~)
class StrikethroughPlugin: Plugin {
    var name: String { return "strikethrough" }

    func initialize(conv converter: Converter) {
        registerStrikethroughRenderers(converter: converter)
    }

    private func registerStrikethroughRenderers(converter: Converter) {
        for tag in ["strike", "s", "del"] {
            converter.registerRenderer(tag) { node, converter in
                let content = try renderChildren(node, converter: converter)
                return applyDelimiterPerLine(content, delimiter: "~~")
            }
        }
    }
}
