import Foundation

extension MultiMarkdownPlugin {
    func registerFigure(conv: Converter) {
        conv.Register.tagType("figure", .block, priority: PriorityEarly)

        // Suppress figcaption — the alt text on <img> already carries the caption
        conv.Register.rendererFor("figcaption", .inline, { ctx, w, n in
            return .success
        }, priority: PriorityEarly)
    }
}
