import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerDividerRenderer(converter: Converter) {
        converter.registerRenderer("hr") { [weak self] _, _ in
            let rule = self?.options.horizontalRule ?? "* * *"
            return "\n\n\(rule)\n\n"
        }
    }
}
