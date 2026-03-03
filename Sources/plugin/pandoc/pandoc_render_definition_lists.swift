import Foundation

extension PandocPlugin {
    func registerDefinitionLists(conv: Converter) {
        conv.Register.rendererFor("dl", .block, { ctx, w, n in
            w.writeString("\n\n")
            ctx.renderChildNodes(w, n)
            w.writeString("\n\n")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("dt", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("\(buf.string)\n")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("dd", .block, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString(":   \(buf.string)\n")
            return .success
        }, priority: PriorityEarly)
    }
}
