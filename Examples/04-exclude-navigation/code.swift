import HTMLToMarkdown

// Fetch HTML from a blog post URL
// let html = try String(contentsOf: URL(string: "https://example.com/blog/swift-concurrency")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    // Exclude navigation, sidebar, and footer — keep only main content
    .excludeSelectors(["nav.site-nav", "aside.sidebar", "footer.site-footer"])
])
print(markdown)
