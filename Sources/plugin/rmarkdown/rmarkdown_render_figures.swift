import Foundation
import SwiftSoup

extension RMarkdownPlugin {
    func registerFigureCaptions(conv: Converter) {
        conv.Register.rendererFor("figure", .block, { ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard let img = try? element.select("img").first() else { return .tryNext }
            let src = (try? img.attr("src")) ?? ""
            guard !src.isEmpty else { return .tryNext }
            let caption = (try? element.select("figcaption").first()?.text()) ?? ""
            let alt = caption.isEmpty ? ((try? img.attr("alt")) ?? "") : caption
            w.writeString("\n\n![\(alt)](\(src))\n\n")
            return .success
        }, priority: PriorityEarly)
    }
}
