import Foundation
import SwiftSoup

extension CommonmarkPlugin {

    func registerImageRenderers(converter: Converter) {
        converter.registerRenderer("img") { [weak self] node, converter in
            guard let element = node as? Element else { return nil }
            guard let self = self else { return nil }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = self.assembleAbsoluteURL(rawSrc, domain: converter.getOptions().baseDomain)
            if src.isEmpty { return "" }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let alt = escapeAltText(rawAlt)

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            if title.isEmpty {
                return "![\(alt)](\(src))"
            } else {
                return "![\(alt)](\(src) \(self.formatLinkTitle(title)))"
            }
        }
    }
}

/// Escape [ and ] characters in image alt text (matches Go's escapeAlt function)
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
