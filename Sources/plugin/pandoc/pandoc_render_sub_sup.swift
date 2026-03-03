import Foundation

extension PandocPlugin {
    func registerSubSup(conv: Converter) {
        conv.Register.rendererFor("sub", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("~\(buf.string)~")
            return .success
        }, priority: PriorityEarly)

        conv.Register.rendererFor("sup", .inline, { ctx, w, n in
            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            w.writeString("^\(buf.string)^")
            return .success
        }, priority: PriorityEarly)
    }
}
