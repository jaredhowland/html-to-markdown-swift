import Foundation
import SwiftSoup

extension CommonmarkPlugin {
    func registerImageRenderers(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { [weak self] ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard let self = self else { return .tryNext }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = defaultAssembleAbsoluteURL(rawSrc, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            if src.isEmpty { w.writeString(""); return .success }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let alt = escapeAltText(rawAlt)

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            if title.isEmpty {
                w.writeString("![\(alt)](\(src))")
            } else {
                w.writeString("![\(alt)](\(src) \(self.formatLinkTitle(title)))")
            }
            return .success
        }, priority: PriorityStandard)
    }
}

private func escapeAltText(_ alt: String) -> String {
    var result = ""
    let chars = Array(alt)
    for (i, ch) in chars.enumerated() {
        if ch == "[" || ch == "]" {
            let prevIndex = i - 1
            if prevIndex < 0 || chars[prevIndex] != "\\" {
                result.append("\\")
            }
        }
        result.append(ch)
    }
    return result
}
