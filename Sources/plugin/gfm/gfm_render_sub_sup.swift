import Foundation

extension GFMPlugin {
    func registerSubSup(conv: Converter) {
        conv.Register.rendererFor("sub", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("<sub>\(buf.string)</sub>")
            return .success
        }, priority: PriorityStandard)

        conv.Register.rendererFor("sup", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("<sup>\(buf.string)</sup>")
            return .success
        }, priority: PriorityStandard)
    }
}
