import Foundation
import SwiftSoup

extension RMarkdownPlugin {
    func registerTabsets(conv: Converter) {
        conv.Register.rendererFor("div", .block, { ctx, w, n in
            guard let element = n as? Element,
                  element.hasClass("tabset") else { return .tryNext }

            // Build id → name map from <ul class="nav"> > <li> > <a>
            var tabNames: [String: String] = [:]
            let navLinks = (try? element.select("ul.nav > li > a")) ?? Elements()
            for link in navLinks {
                let href = (try? link.attr("href")) ?? ""
                let name = (try? link.text()) ?? href
                let id = href.hasPrefix("#") ? String(href.dropFirst()) : href
                if !id.isEmpty {
                    tabNames[id] = name
                }
            }

            // Render each tab-pane as a ## section
            let panes = (try? element.select("div.tab-content > div.tab-pane")) ?? Elements()
            if !panes.isEmpty {
                w.writeString("\n\n")
                for pane in panes {
                    let paneId = pane.id()
                    let tabName = tabNames[paneId] ?? paneId
                    w.writeString("## \(tabName)\n\n")
                    ctx.renderChildNodes(w, pane)
                    w.writeString("\n\n")
                }
            } else {
                // Fallback: render children
                ctx.renderChildNodes(w, n)
            }
            return .success
        }, priority: PriorityEarly)
    }
}
