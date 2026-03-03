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
    .excludeSelectors([
        "#mw-navigation",
        "#mw-head",
        "#mw-panel",
        ".mw-editsection",
        ".navbox",
        ".reflist",
        "#toc",
        ".mw-jump-link",
        ".catlinks",
        "#footer",
        ".vector-header",
        ".vector-sidebar",
        ".vector-toc",
        ".mw-portlet",
        "#p-search",
        ".mw-footer",
        "#vector-page-titlebar-toc",
        "#vector-page-tools-dropdown",
        "#p-lang-btn",
        "#siteNotice",
        "#siteSub",
        "#contentSub",
        ".mw-authority-control",
        ".printfooter",
        ".vector-page-toolbar",
        "#p-views",
        "#p-tb",
        ".vector-appearance-landmark",
        "#vector-appearance-dropdown"
    ])
])
print(markdown)

