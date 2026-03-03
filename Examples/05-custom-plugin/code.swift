import HTMLToMarkdown

// Custom plugin that renders heading text in uppercase
final class UppercaseHeadingsPlugin: Plugin {
    var name: String { return "uppercase-headings" }

    func initialize(conv: Converter) throws {
        for (tag, level) in [("h1",1),("h2",2),("h3",3),("h4",4),("h5",5),("h6",6)] {
            let l = level
            conv.Register.rendererFor(tag, .block, { ctx, w, node in
                let buf = StringWriter()
                ctx.renderChildNodes(buf, node)
                let prefix = String(repeating: "#", count: l)
                w.writeString("\n\n\(prefix) \(buf.string.uppercased())")
                return .success
            }, priority: PriorityStandard - 1)
        }
    }
}

let html = """
<h1>Main Title</h1>
<p>This example demonstrates writing a <strong>custom plugin</strong>.</p>
<h2>Section One</h2>
<p>The custom plugin transforms all heading text to uppercase.</p>
<h2>Section Two</h2>
<p>Plugins can intercept rendering of any HTML element.</p>
<h3>Subsection</h3>
<p>They can also register text transformers, pre-renderers, and post-renderers.</p>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    UppercaseHeadingsPlugin()
])
print(markdown)
