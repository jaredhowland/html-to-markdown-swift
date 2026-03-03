import HTMLToMarkdown

// Fetch HTML from https://en.wikipedia.org/wiki/Markdown
// let html = try String(contentsOf: URL(string: "https://en.wikipedia.org/wiki/Markdown")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    TablePlugin()
], options: [
    // Resolve relative wiki links against the Wikipedia base domain
    .domain("https://en.wikipedia.org"),
    // Strip Wikipedia chrome — keep only article content
    .excludeSelectors(["#mw-navigation", "#mw-footer", ".mw-editsection"])
])
print(markdown)
