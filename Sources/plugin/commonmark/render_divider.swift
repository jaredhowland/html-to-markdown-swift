import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerDividerRenderer(conv: Converter) {
        conv.Register.rendererFor("hr", .block, { [weak self] ctx, w, _ in
            let rule = self?.options.horizontalRule ?? "* * *"
            w.writeString("\n\n\(rule)\n\n")
            return .success
        }, priority: PriorityStandard)
    }
}
