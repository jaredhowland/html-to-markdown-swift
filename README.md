# html-to-markdown-swift v2.5.0 (Swift)

A robust, fully featured Swift port of [html-to-markdown](https://github.com/JohannesKaufmann/html-to-markdown) — convert HTML (even entire websites) into clean, readable Markdown.

## Features

- ✅ Handles **deeply nested** and malformed HTML
- ✅ Full [CommonMark](https://commonmark.org/) support
- ✅ [GitHub Flavored Markdown](https://github.github.com/gfm/) (GFM) — tables, task lists, strikethrough
- ✅ Extensible **plugin system** — add custom renderers, pre/post processors, and text transformers
- ✅ Domain resolution — relative links become absolute URLs
- ✅ CSS selector–based **include/exclude** filtering
- ✅ Smart **escaping** (only escapes when necessary)
- ✅ Thread-safe converter instances

## Usage

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/html-to-markdown-swift.git", from: "2.5.0")
]
```

Add to your target:

```swift
.product(name: "HTMLToMarkdown", package: "html-to-markdown-swift")
```

### Basic Conversion

```swift
import HTMLToMarkdown

let html = "<strong>Bold</strong> and <em>italic</em>"
let markdown = try HTMLToMarkdown.convert(html)
// **Bold** and _italic_
```

### With Domain

Convert relative links to absolute URLs:

```swift
let html = "<a href=\"/about\">About</a>"
let markdown = try HTMLToMarkdown.convert(html, options: [.domain("https://example.com")])
// [About](https://example.com/about)
```

### With Plugins

```swift
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    GFMPlugin()
])
```

## Collapse & Tag Types

Each HTML element has a *tag type* — `block`, `inline`, or `remove`. This controls how whitespace and newlines are handled around elements. You can override the type for any tag:

```swift
// Treat <div> as inline instead of block
conv.Register.tagType("div", .inline, priority: PriorityEarly)

// Remove an element from output
conv.Register.tagType("nav", .remove)
```

## Plugins

| Name | Description |
|------|-------------|
| `BasePlugin` | Core functionality: default tag types, removes `<script>`, `<style>`, `<input>` |
| `CommonmarkPlugin` | CommonMark spec: headings, bold, italic, links, images, code, lists, blockquotes, etc. |
| `GFMPlugin` | GitHub Flavored Markdown: bundles Strikethrough, Table, TaskListItems + definition lists, details/summary, sub/sup, abbreviations |
| `TaskListItemsPlugin` | Converts `<input type="checkbox">` in list items to `- [x]` / `- [ ]` |
| `StrikethroughPlugin` | Converts `<strike>`, `<s>`, `<del>` to `~~text~~` |
| `TablePlugin` | Converts HTML tables to GFM-style pipe tables |
| `VimeoEmbedPlugin` | Converts Vimeo `<iframe>` embeds to `[Title](https://vimeo.com/ID)` links |
| `YouTubeEmbedPlugin` | Converts YouTube `<iframe>` embeds to clickable thumbnail images |
| `AtlassianPlugin` | Atlassian/Confluence: autolinks, image sizing, Confluence code macros, attachment links |
| `MultiMarkdownPlugin` | MultiMarkdown 4: sub/sup, definition lists, image attributes, figure/figcaption, footnotes |
| `MarkdownExtraPlugin` | PHP Markdown Extra: definition lists, footnotes, header IDs `{#id}`, abbreviation reference list |
| `PandocPlugin` | Pandoc Markdown: LaTeX math (`$...$`, `$$...$$`), definition lists, footnotes, sub/sup `^x^`/`~x~`, header IDs |
| `RMarkdownPlugin` | R Markdown (extends Pandoc): tabsets → `##` sections, figure captions from `<figcaption>` |
| `FrontmatterPlugin` | Extracts page metadata (`<title>`, `<meta>`) and prepends YAML frontmatter |
| `TypographyPlugin` | Bundles SmartQuotesPlugin, ReplacementsPlugin, LinkifyPlugin; configure with `smartQuotes`/`replacements`/`linkify` flags and `quoteStyle` (`.english`, `.german`, `.french`, `.swedish`) |
| `SmartQuotesPlugin` | Converts straight `"` and `'` to typographic quotes; locale-aware styles; skips code regions; handles `<q>` elements |
| `ReplacementsPlugin` | `(c)`→`©`, `(r)`→`®`, `(tm)`→`™`, `+-`→`±`, `...`→`…`, `---`→`—`, `--`→`–`; skips code regions |
| `LinkifyPlugin` | Converts bare `https://`/`http://` URLs to `[url](url)` links; handles parentheses in URLs; skips code regions and existing Markdown links |
| `ReferenceLinkPlugin` | `plugin/referencelinks` | Numbered reference-style links at document bottom (deduplication, titles); `inlineLinks: true` to revert to inline |
| `EmojiPlugin` | `plugin/emoji` | GitHub emoji `:shortcode:` output from `<img class="emoji">` and Unicode emoji conversion; bundled 1900+ entry table |

### ReferenceLinkPlugin

```swift
let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(ReferenceLinkPlugin()) // reference-style links (default)
// Or: ReferenceLinkPlugin(inlineLinks: true)   // revert to inline links
let markdown = try conv.convertString(html)
```

### EmojiPlugin

```swift
let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(EmojiPlugin())                        // :shortcode: output (default)
// Or: EmojiPlugin(outputStyle: .unicode)                      // Unicode emoji output
let markdown = try conv.convertString(html)
```

### Writing a Plugin

Implement the `Plugin` protocol:

```swift
import HTMLToMarkdown

public class MyPlugin: Plugin {
    public var name: String { return "my-plugin" }
    public init() {}

    public func initialize(conv: Converter) throws {
        // Render <aside> as a blockquote
        conv.Register.rendererFor("aside", .block, { ctx, w, node in
            w.writeString("> ")
            ctx.renderChildNodes(w, node)
            return .success
        })

        // Pre-process the DOM before rendering
        conv.Register.preRenderer({ ctx, doc in
            // Modify the SwiftSoup document
        })

        // Post-process the final markdown string
        conv.Register.postRenderer({ ctx, result in
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        })

        // Bundle another plugin as a dependency
        try conv.Register.plugin(CommonmarkPlugin())
    }
}
```

Available registration methods:

| Method | Purpose |
|--------|---------|
| `rendererFor(tag, type, handler)` | Render a specific HTML tag |
| `renderer(handler)` | Catch-all renderer for all tags |
| `preRenderer(handler, priority)` | Transform DOM before rendering |
| `postRenderer(handler, priority)` | Transform final markdown string |
| `textTransformer(handler)` | Transform text node content |
| `escapedChar(char)` | Mark a character as needing escaping |
| `unEscaper(handler)` | Control when a character is unescaped |
| `tagType(tag, type, priority)` | Override block/inline/remove classification |
| `plugin(plugin)` | Register a sub-plugin dependency |

## Examples

See the [`Examples/`](Examples/) directory for complete runnable examples:

- [01 - Basic Conversion](Examples/01-basic-conversion/)
- [02 - Vita with Frontmatter](Examples/02-vita-with-frontmatter/)
- [03 - Wikipedia Article](Examples/03-wikipedia-article/)
- [04 - Exclude Navigation](Examples/04-exclude-navigation/)
- [05 - Custom Plugin](Examples/05-custom-plugin/)
- [06 - GFM Features](Examples/06-gfm-features/)
- [07 - Atlassian Markdown](Examples/07-atlassian-markdown/)
- [08 - MultiMarkdown](Examples/08-multimarkdown/)
- [09 - YouTube & Vimeo Embeds](Examples/09-youtube-vimeo/)
- [10 - Atlassian Confluence](Examples/10-atlassian-confluence/)
- [11 - Markdown Extra](Examples/11-markdown-extra/)
- [12 - Pandoc](Examples/12-pandoc/)
- [13 - R Markdown](Examples/13-rmarkdown/)
- [14 - Typography](Examples/14-typography/)
- [15 - Reference Links](Examples/15-reference-links/)
- [16 - Emoji](Examples/16-emoji/)

## FAQ

**Can I extend the converter with custom rules?**  
Yes — implement the `Plugin` protocol and register renderers, pre/post processors, or text transformers in `initialize(conv:)`.

**Is the output safe to display in a browser?**  
This library converts HTML *to* Markdown — it does not sanitize HTML. If you need XSS protection, sanitize the input HTML before conversion or the output Markdown before rendering.

**Is it thread-safe?**  
Yes. Each `Converter` instance is protected by an internal lock and safe for concurrent use from multiple threads.

**Why does my `[` get escaped as `\[`?**  
The converter automatically escapes characters that would trigger unintended Markdown formatting. If you're writing a custom renderer, use `w.writeString(...)` directly (bypasses text transformation) instead of writing to a child context.

**How do I run the tests?**  
```sh
swift test
```

Many tests use golden files in `Tests/data/` — an input HTML file and an expected Markdown output file. To update golden files after intentional output changes, update the `.out.md` files accordingly.

**How do I contribute?**  
Issues and pull requests are welcome. Please ensure all tests pass (`swift test`) and add tests for new behaviour.

## License

MIT License. This Swift port is based on [html-to-markdown](https://github.com/JohannesKaufmann/html-to-markdown) by [Johannes Kaufmann](https://github.com/JohannesKaufmann). HTML parsing uses [SwiftSoup](https://github.com/scinfu/SwiftSoup).

