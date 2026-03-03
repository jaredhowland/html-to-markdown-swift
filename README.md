# HTML to Markdown - Swift Port

A robust, fully featured Swift port of the popular [html-to-markdown](https://github.com/JohannesKaufmann/html-to-markdown) Go library. Converts HTML (even entire websites) into clean, readable Markdown with support for complex formatting, customizable options, and an extensible plugin system.

## Features

✨ **Core Markdown Support**
- ✅ Bold & Italic: Supports `<strong>`, `<b>`, `<em>`, `<i>` tags with customizable delimiters
- ✅ Lists: Full support for unordered (`<ul>`) and ordered (`<ol>`) lists with nesting
- ✅ Links: Proper handling of `<a>` tags with URLs and titles
- ✅ Images: Converts `<img>` tags with alt text and titles
- ✅ Blockquotes: Handles `<blockquote>` elements including nesting
- ✅ Code: Inline code with `` `backticks` `` and code blocks with triple backticks
- ✅ Headings: All heading levels `<h1>` through `<h6>`
- ✅ Horizontal Rules: Converts `<hr>` to `---`
- ✅ Line Breaks: Converts `<br>` to two spaces and newline
- ✅ Comments: Removes HTML comments from output

🔌 **Plugin System**
- Extensible plugin architecture for custom conversion rules
- Built-in plugins: Base, Commonmark, Strikethrough, Table
- Easy to register custom renderers for specific tags

⚙️ **Customization**
- Domain resolution for converting relative links to absolute URLs
- CSS selector-based include/exclude filtering
- Smart escaping (automatic, with option to disable)
- Configurable markdown delimiters
- Custom tag type registration
- Pluggable tag renderers

🔒 **Thread-Safe**
- Safe for use in concurrent contexts with proper synchronization

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/jaredhowland/html-to-markdown.git", from: "2.5.0")
]
```

Add to your target:
```swift
.product(name: "HTMLToMarkdown", package: "html-to-markdown")
```

## Usage

### Basic Conversion

```swift
import HTMLToMarkdown

let html = "<strong>Bold Text</strong>"
let markdown = try HTMLToMarkdown.convert(html)
print(markdown)  // Output: **Bold Text**
```

### Convert HTML Data

```swift
let data = htmlString.data(using: .utf8)!
let markdown = try HTMLToMarkdown.convert(data: data)
```

### With Custom Domain

Convert relative links to absolute URLs:

```swift
let html = "<a href=\"/about\">About</a>"
let markdown = try HTMLToMarkdown.convert(html, options: [
    .domain("https://example.com")
])
// Output: [About](https://example.com/about)
```

### With Custom Plugins

Use specific plugins and configure options:

```swift
let html = "<strong>Bold</strong> and ~~strikethrough~~"
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    StrikethroughPlugin()
])
```

### Create a Persistent Converter

```swift
let converter = HTMLToMarkdown.createConverter(
    plugins: [
        BasePlugin(),
        CommonmarkPlugin(),
        TablePlugin()
    ],
    options: [
        .domain("https://example.com")
    ]
)

let md1 = try converter.convertString(html1)
let md2 = try converter.convertString(html2)
```

## Plugin Documentation

### Built-In Plugins

#### BasePlugin

Provides fundamental HTML structure handling:
- Removes unwanted tags (style, script, meta, link, noscript)
- Sets default tag types (block vs inline)
- Handles default rendering for unregistered tags

```swift
let converter = HTMLToMarkdown.createConverter(plugins: [BasePlugin()])
```

#### CommonmarkPlugin

Implements CommonMark Markdown specification with customizable options:

```swift
var options = CommonmarkOptions()
options.strongDelimiter = "__"  // Use __ instead of **
options.emDelimiter = "_"        // Use _ instead of *
options.codeDelimiter = "`"      // Backtick for inline code
options.linkStyle = .inlined     // Use [text](url) format

let converter = HTMLToMarkdown.createConverter(plugins: [
    BasePlugin(),
    CommonmarkPlugin(options: options)
])
```

#### StrikethroughPlugin

Adds support for strikethrough text using GitHub Flavored Markdown syntax:

```swift
let html = "<strike>Strikethrough</strike>"
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    StrikethroughPlugin()
])
// Output: ~~Strikethrough~~
```

Supports tags: `<strike>`, `<s>`, `<del>`

#### TablePlugin

Converts HTML tables to GitHub Flavored Markdown tables:

```swift
let html = """
<table>
    <thead>
        <tr><th>Name</th><th>Age</th></tr>
    </thead>
    <tbody>
        <tr><td>Alice</td><td>30</td></tr>
        <tr><td>Bob</td><td>25</td></tr>
    </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    TablePlugin()
])
```

Output:
```markdown
| Name | Age |
| --- | --- |
| Alice | 30 |
| Bob | 25 |
```

#### GFMPlugin

Bundles `StrikethroughPlugin` and `TablePlugin`, and adds task lists, definition lists, details/summary, subscript/superscript, and abbreviations:

```swift
let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(GFMPlugin())  // Includes strikethrough, tables, task lists, and more
```

> **Note:** `GFMPlugin` bundles `StrikethroughPlugin` and `TablePlugin`, so you don't need to register those separately when using `GFMPlugin`.

Supported features:
- **Task lists**: `<input type="checkbox">` inside `<li>` → `- [x]` / `- [ ]`
- **Definition lists**: `<dl>`, `<dt>`, `<dd>` → bold terms with colon-prefixed definitions
- **Details/Summary**: `<details>`/`<summary>` → bold summary followed by content
- **Subscript/Superscript**: `<sub>`/`<sup>` → HTML passthrough (`<sub>text</sub>`, `<sup>text</sup>`)
- **Abbreviations**: `<abbr title="...">` → `text (expansion)`

#### FrontmatterPlugin

Prepends a YAML frontmatter block to the converted markdown output. Extracts metadata from `<head>` (title, author, description, keywords/tags) and computes word count and reading time from the rendered markdown.

**Frontmatter fields:**

| Field | Source |
|---|---|
| `title` | `<title>` or `og:title` |
| `author` | `meta[name=author]` or `og:author` |
| `source` | `.domain` converter option |
| `url` | `<link rel=canonical>` or `.domain` |
| `date_saved` | Current time (ISO 8601) |
| `word_count` | Counted from rendered markdown |
| `reading_time` | `ceil(words / 200)` min |
| `description` | `meta[name=description]` or `og:description` |
| `tags` | `meta[name=keywords]`, `article:tag`, schema.org ld+json |

Fields are omitted when not found. `date_saved`, `word_count`, and `reading_time` are always present.

**Registration:**

```swift
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    .domain("https://example.com")
])
```

**Example output:**

```yaml
---
title: "My Page Title"
author: "Jane Doe"
source: "https://example.com"
url: "https://example.com/page/"
date_saved: "2026-03-03T20:34:57Z"
word_count: "312"
reading_time: "2 min"
description: "Page description here."
tags:
  - "swift"
  - "ios"
---

{markdown content}
```

#### AtlassianPlugin

Targets [Bitbucket/Atlassian Markdown](https://confluence.atlassian.com/bitbucketserver/markdown-syntax-guide-776639995.html). Bundles `StrikethroughPlugin` and `TablePlugin`, and adds:

```swift
let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(AtlassianPlugin())  // Includes strikethrough, tables, autolinks, image sizing
```

> **Note:** `AtlassianPlugin` bundles `StrikethroughPlugin` and `TablePlugin`, so you don't need to register those separately.

Supported features:
- **Autolinks**: `<a href="url">url</a>` where link text equals the href → bare URL (Atlassian auto-detects URLs)
- **Image sizing**: `<img width="640" height="480">` → `![alt](src){width=640 height=480}`

#### MultiMarkdownPlugin

Targets [MultiMarkdown 4](https://fletcher.github.io/MultiMarkdown-4/MMD_Users_Guide.html). Bundles `StrikethroughPlugin` and `TablePlugin`, and adds:

```swift
let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(MultiMarkdownPlugin())  // Includes strikethrough, tables, MMD-specific syntax
```

> **Note:** `MultiMarkdownPlugin` bundles `StrikethroughPlugin` and `TablePlugin`, so you don't need to register those separately.

Supported features:
- **Subscript/Superscript**: `<sub>text</sub>` → `~text~`, `<sup>text</sup>` → `^text^`
- **Definition lists**: `<dl>/<dt>/<dd>` → MMD format (plain term + `:   definition`)
- **Image attributes**: `<img width="640" height="480">` → `![alt](src){width=640px height=480px}`
- **Figure/Figcaption**: `<figure>` treated as block; `<figcaption>` suppressed (caption is in `alt`)
- **Footnotes**: `<a class="footnote" href="#fn:1">` → `[^1]`; `<div class="footnotes">` → `[^1]: text` at bottom

## Converter Options

### Domain Resolution

```swift
.domain("https://example.com")
```

Resolves relative URLs to absolute URLs using the provided domain.

### CSS Selectors

```swift
.excludeSelectors([".ads", ".footer", "nav"])
.includeSelector("article")
```

- `excludeSelectors`: Remove elements matching these CSS selectors
- `includeSelector`: Only include elements matching this selector (excludes everything else)

### Escape Mode

By default, special characters are escaped only when they would trigger unintended Markdown formatting. To disable all escaping:

```swift
.escapeMode(.disabled) // Don't escape special characters
```

### Custom Tag Configuration

```swift
.tagTypeConfiguration { registry in
    registry.register(tagName: "custom-block", type: .block, priority: .standard)
    registry.register(tagName: "custom-inline", type: .inline, priority: .standard)
}
```

## Advanced Usage

### Writing a Custom Plugin

Implement the `Plugin` protocol — provide a `name` and register handlers in `initialize(conv:)`:

```swift
import HTMLToMarkdown

public class MyPlugin: Plugin {
    public var name: String { return "my-plugin" }

    public init() {}

    public func initialize(conv: Converter) throws {
        // Render a specific HTML tag
        conv.Register.rendererFor("aside", .block, { ctx, w, node in
            w.writeString("> ")
            ctx.renderChildNodes(w, node)
            return .success
        })

        // Transform text node content
        conv.Register.textTransformer({ ctx, text in
            return text.replacingOccurrences(of: "foo", with: "bar")
        })

        // Mark a character as needing escaping
        conv.Register.escapedChar("@")

        // Register another plugin as a dependency
        try conv.Register.plugin(CommonmarkPlugin())
    }
}

// Use it:
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    MyPlugin()
])
```

Available registration methods on `conv.Register`:

| Method | Purpose |
|---|---|
| `rendererFor(tag, type, handler)` | Handle a specific HTML tag |
| `renderer(handler)` | Catch-all renderer (all tags) |
| `preRenderer(handler)` | Transform DOM before rendering |
| `postRenderer(handler)` | Transform final markdown string |
| `textTransformer(handler)` | Transform text node content |
| `escapedChar(char)` | Mark a character as needing escaping |
| `unEscaper(handler)` | Control when a character is unescaped |
| `tagType(tag, type)` | Override block/inline classification |
| `plugin(plugin)` | Register a sub-plugin dependency |

## Examples

### Complete Website Conversion

```swift
import HTMLToMarkdown

let htmlContent = """
<article>
    <h1>Blog Post Title</h1>
    <p>Written by <strong>John Doe</strong></p>
    <p>This is an <em>interesting</em> article about web development.</p>
    <h2>Key Points</h2>
    <ul>
        <li>Point 1</li>
        <li>Point 2</li>
        <li>Point 3</li>
    </ul>
    <blockquote>
        <p>A quote from an expert</p>
    </blockquote>
    <p>Check out <a href="https://example.com">our website</a></p>
</article>
"""

let markdown = try HTMLToMarkdown.convert(htmlContent)
```

### GitHub Flavored Markdown

```swift
let html = """
<p>This is <strong>bold</strong>, <em>italic</em>, and ~~strikethrough~~.</p>
<table>
    <tr><th>Feature</th><th>Status</th></tr>
    <tr><td>Bold</td><td>✓</td></tr>
    <tr><td>Italic</td><td>✓</td></tr>
    <tr><td>Strikethrough</td><td>✓</td></tr>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    StrikethroughPlugin(),
    TablePlugin()
])
```

## Compatibility

- **Swift Version**: 5.5 or later
- **Platforms**: 
  - macOS 10.15+
  - iOS 13+
  - tvOS 13+
  - watchOS 6+

## Thread Safety

The converter is thread-safe and can be safely used from multiple threads simultaneously. Each conversion operation is protected by an internal lock.

## Performance

The converter is optimized for performance:
- Efficient HTML parsing using SwiftSoup
- Minimal memory allocations
- Streaming-friendly architecture

## Error Handling

All conversion errors are reported as `ConversionError`:

```swift
do {
    let markdown = try HTMLToMarkdown.convert(html)
} catch let error as ConversionError {
    switch error {
    case .invalidHTML(let message):
        print("Invalid HTML: \(message)")
    case .conversionFailed(let message):
        print("Conversion failed: \(message)")
    case .pluginError(let message):
        print("Plugin error: \(message)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Contributing

Issues and pull requests are welcome! When contributing:

1. Ensure all tests pass
2. Add tests for new features
3. Follow Swift naming conventions

## Licensing

This Swift port is licensed under the MIT License, with attribution to the original Go project by Johannes Kaufmann.

### License

MIT License - See LICENSE file for details

## Original Project

This is a Swift port of [html-to-markdown by Johannes Kaufmann](https://github.com/JohannesKaufmann/html-to-markdown) (Go).

The port maintains feature parity with the Go version while adapting the API to Swift conventions and best practices.

## Acknowledgments

- Original Go library by [Johannes Kaufmann](https://github.com/JohannesKaufmann)
- HTML parsing using [SwiftSoup](https://github.com/scinfu/SwiftSoup)
