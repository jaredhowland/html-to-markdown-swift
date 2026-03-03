import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerBreakRenderer(converter: Converter) {
        converter.registerRenderer("br") { _, _ in
            return "  \n"
        }
    }
}
