import Foundation
import SwiftSoup

extension Converter {

    func handleRenderNodes(ctx: Context, w: StringWriter, nodes: [Node]) {
        for node in nodes { handleRenderNode(ctx: ctx, w: w, node: node) }
    }

    @discardableResult
    func handleRenderNode(ctx: Context, w: StringWriter, node: Node) -> RenderStatus {
        let name = node.nodeName().lowercased()

        if name == "#text", let textNode = node as? TextNode {
            return handleRenderText(ctx: ctx, w: w, node: textNode)
        }

        for handler in getRenderHandlers() {
            let status = handler(ctx, w, node)
            if status == .success { return .success }
        }

        return handleFallback(ctx: ctx, w: w, node: node)
    }

    func handleFallback(ctx: Context, w: StringWriter, node: Node) -> RenderStatus {
        let tagName = node.nodeName().lowercased()
        let type = getTagType(tagName)
        if type == .remove { return .success }
        if type == .block { w.writeString("\n\n") }
        ctx.renderChildNodes(w, node)
        if type == .block { w.writeString("\n\n") }
        return .success
    }

    private func handleRenderText(ctx: Context, w: StringWriter, node: TextNode) -> RenderStatus {
        var content = node.getWholeText()
        for handler in getTextTransformHandlers() {
            content = handler(ctx, content)
        }
        w.writeString(content)
        return .success
    }
}
