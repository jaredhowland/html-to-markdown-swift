import Foundation
import SwiftSoup

extension PandocPlugin {
    func registerHeaderIds(conv: Converter) {
        for level in 1...6 {
            let tag = "h\(level)"
            conv.Register.rendererFor(tag, .block, { ctx, w, n in
                guard let element = n as? Element else { return .tryNext }
                let id = (try? element.attr("id")) ?? ""
                guard !id.isEmpty else { return .tryNext }
                let buf = StringWriter()
                ctx.renderChildNodes(buf, n)
                let trimmed = buf.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { return .tryNext }
                let hashes = String(repeating: "#", count: level)
                w.writeString("\n\n\(hashes) \(trimmed) {#\(id)}\n\n")
                return .success
            }, priority: PriorityEarly)
        }
    }
}
