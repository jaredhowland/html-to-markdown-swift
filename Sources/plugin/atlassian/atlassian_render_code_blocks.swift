import Foundation
import SwiftSoup

extension AtlassianPlugin {
    func registerCodeBlocks(conv: Converter) {
        // Pre-render: convert Confluence code macros to standard <pre><code> elements
        conv.Register.preRenderer({ ctx, doc in
            let macros = (try? doc.getElementsByTag("ac:structured-macro")) ?? Elements()
            for macro in macros {
                guard (try? macro.attr("ac:name")) == "code" else { continue }

                // Extract language from <ac:parameter ac:name="language">
                let language = (try? macro.getElementsByTag("ac:parameter")
                    .filter { (try? $0.attr("ac:name")) == "language" }
                    .first?.text()) ?? ""

                // Extract code from <ac:plain-text-body>
                let codeText = (try? macro.getElementsByTag("ac:plain-text-body").first()?.text()) ?? ""

                // Build a <pre><code> element
                guard let pre = try? Element(Tag.valueOf("pre"), ""),
                      let code = try? Element(Tag.valueOf("code"), "") else { continue }
                if !language.isEmpty { try? code.attr("class", "language-\(language)") }
                try? code.text(codeText)
                try? pre.appendChild(code)
                try? macro.replaceWith(pre)
            }
        }, priority: PriorityEarly)
    }
}
