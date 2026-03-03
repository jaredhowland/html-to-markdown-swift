import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerCommentRenderer(conv: Converter) {
        conv.Register.renderer({ _, w, n in
            guard n.nodeName().lowercased() == "#comment" else { return .tryNext }
            if let comment = n as? Comment, comment.getData() == "THE END" {
                w.writeString("\n\n<!--THE END-->\n\n")
                return .success
            }
            w.writeString("")
            return .success
        }, priority: PriorityStandard)
    }
}
