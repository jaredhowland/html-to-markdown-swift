import HTMLToMarkdown

// Fetch HTML from URL (e.g., https://jaredhowland.com/vita)
// let html = try String(contentsOf: URL(string: "https://jaredhowland.com/vita")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    .domain("https://www.jaredhowland.com"),
    // Strip navigation, header, and footer — keep only <main> content
    .excludeSelectors(["header", "footer", "nav"])
])
print(markdown)
