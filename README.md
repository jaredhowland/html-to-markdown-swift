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
