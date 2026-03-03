import Foundation
import SwiftSoup

extension PandocPlugin {
    func registerMath(conv: Converter) {
        // Inline math: <span class="math inline">\(...\)</span> → $...$
        conv.Register.rendererFor("span", .inline, { ctx, w, n in
            guard let element = n as? Element,
                  element.hasClass("math") else { return .tryNext }

            let raw = (try? element.text()) ?? ""
            if element.hasClass("inline") {
                let content = raw
                    .replacingOccurrences(of: "\\(", with: "")
                    .replacingOccurrences(of: "\\)", with: "")
                    .trimmingCharacters(in: .whitespaces)
                w.writeString("$\(content)$")
                return .success
            } else if element.hasClass("display") {
                let content = raw
                    .replacingOccurrences(of: "\\[", with: "")
                    .replacingOccurrences(of: "\\]", with: "")
                    .trimmingCharacters(in: .whitespaces)
                w.writeString("\n\n$$\n\(content)\n$$\n\n")
                return .success
            }
            return .tryNext
        }, priority: PriorityEarly)

        // Display math: <div class="math display">\[...\]</div> → $$\n...\n$$
        conv.Register.rendererFor("div", .block, { ctx, w, n in
            guard let element = n as? Element,
                  element.hasClass("math"),
                  element.hasClass("display") else { return .tryNext }
            let raw = (try? element.text()) ?? ""
            let content = raw
                .replacingOccurrences(of: "\\[", with: "")
                .replacingOccurrences(of: "\\]", with: "")
                .trimmingCharacters(in: .whitespaces)
            w.writeString("\n\n$$\n\(content)\n$$\n\n")
            return .success
        }, priority: PriorityEarly)
    }
}
