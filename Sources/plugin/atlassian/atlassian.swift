import Foundation
import SwiftSoup

public class AtlassianPlugin: Plugin {
    public var name: String { return "atlassian" }
    public init() {}

    public func initialize(conv: Converter) throws {
        try conv.Register.plugin(StrikethroughPlugin())
        try conv.Register.plugin(TablePlugin())
        registerAutolinks(conv: conv)
        registerImageSizing(conv: conv)
    }

    // MARK: - Autolinks

    private func registerAutolinks(conv: Converter) {
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

    // MARK: - Image sizing

    private func registerImageSizing(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            let width = (try? element.attr("width")) ?? ""
            let height = (try? element.attr("height")) ?? ""
            if width.isEmpty && height.isEmpty { return .tryNext }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = defaultAssembleAbsoluteURL(rawSrc, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            if src.isEmpty { w.writeString(""); return .success }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let alt = atlassianEscapeAlt(rawAlt)

            let rawTitle = (try? element.attr("title")) ?? ""
            let title = rawTitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            let imgMD: String
            if title.isEmpty {
                imgMD = "![\(alt)](\(src))"
            } else {
                imgMD = "![\(alt)](\(src) \"\(title)\")"
            }

            var parts: [String] = []
            if !width.isEmpty { parts.append("width=\(width)") }
            if !height.isEmpty { parts.append("height=\(height)") }
            let sizing = "{\(parts.joined(separator: " "))}"

            w.writeString(imgMD + sizing)
            return .success
        }, priority: PriorityEarly)
    }
}

private func atlassianEscapeAlt(_ alt: String) -> String {
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
