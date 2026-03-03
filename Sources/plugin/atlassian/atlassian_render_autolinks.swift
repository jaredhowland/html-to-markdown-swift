import Foundation
import SwiftSoup

extension AtlassianPlugin {
    func registerAutolinks(conv: Converter) {
        conv.Register.rendererFor("a", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            let rawHref = (try? element.attr("href")) ?? ""
            let href = defaultAssembleAbsoluteURL(rawHref, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            // Use plain text for comparison to avoid markdown-escaping false negatives
            let plainText = ((try? element.text()) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !href.isEmpty && plainText == href {
                w.writeString(href)
                return .success
            }
            return .tryNext
        }, priority: PriorityEarly)
    }
}
