import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerBreakRenderer(conv: Converter) {
        conv.Register.rendererFor("br", .inline, { _, w, _ in
            w.writeString("  \n")
            return .success
        }, priority: PriorityStandard)
    }
}
