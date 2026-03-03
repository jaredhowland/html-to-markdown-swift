import Foundation

extension GFMPlugin {
    func registerDetailsSummary(conv: Converter) {
        conv.Register.rendererFor("details", .block, { ctx, w, n in
            w.writeString("\n\n")
            ctx.renderChildNodes(w, n)
            w.writeString("\n\n")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("summary", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("**\(buf.string)**\n\n")
            return .success
        }, priority: PriorityStandard)
    }
}
