import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerCommentRenderer(converter: Converter) {
        converter.registerRenderer("#comment") { node, _ in
            if let comment = node as? Comment, comment.getData() == "THE END" {
                return "\n\n<!--THE END-->\n\n"
            }
            return ""
        }
    }
}
