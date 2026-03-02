import Foundation
import SwiftSoup

/// Plugin for strikethrough text support (~~text~~)
class StrikethroughPlugin: Plugin {
    func register(with converter: Converter) {
        registerStrikethroughRenderers(converter: converter)
    }
    
    private func registerStrikethroughRenderers(converter: Converter) {
        for tag in ["strike", "s", "del"] {
            converter.registerRenderer(tag) { node, converter in
                let content = try renderChildren(node, converter: converter)
                let clean = content.trimmingCharacters(in: .whitespaces)
                return "~~\(clean)~~"
            }
        }
    }
}
