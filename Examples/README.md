# Examples for html-to-markdown-swift v2.5.0

This folder contains runnable examples demonstrating usage of html-to-markdown-swift v2.5.0 and its plugins. Each example directory includes a `code.swift` file showing the exact Swift code used to perform the conversion and (in many cases) the generated output in separate files.

How to run

- Open the example's `code.swift` in Xcode or run with `swift run` if the example is wired into a small executable.
- Each `code.swift` imports `HTMLToMarkdown` and shows how to register plugins and options used for that example.

Index of examples (with the main code excerpt from each):


## 01 - Basic Conversion
Demonstrates the core API (headings, lists, links, code blocks, blockquotes).

Code (Examples/01-basic-conversion/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1>Hello, World!</h1>
<p>This is a <strong>basic</strong> HTML-to-Markdown conversion example.</p>
<p>It supports:</p>
<ul>
  <li><strong>Bold</strong> and <em>italic</em> text</li>
  <li><a href="https://example.com">Links</a></li>
  <li>Lists (ordered and unordered)</li>
  <li>Code: <code>let x = 42</code></li>
</ul>
<h2>Code Block</h2>
<pre><code class="language-swift">
let converter = HTMLToMarkdown.createConverter(
    plugins: [BasePlugin(), CommonmarkPlugin()]
)
let markdown = try converter.convertString(html)
</code></pre>
<blockquote>
  <p>Simple things should be simple, complex things should be possible.</p>
</blockquote>
<ol>
  <li>First item</li>
  <li>Second item</li>
  <li>Third item</li>
</ol>
"""

// Default conversion uses BasePlugin + CommonmarkPlugin
let markdown = try HTMLToMarkdown.convert(html)
print(markdown)
```


## 02 - Vita with Frontmatter
Demonstrates `FrontmatterPlugin` and excluding navigation/footer selectors.

Code (Examples/02-vita-with-frontmatter/code.swift):

```swift
import HTMLToMarkdown

// Fetch HTML from https://jaredhowland.com/vita
// let html = try String(contentsOf: URL(string: "https://jaredhowland.com/vita")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    .domain("https://www.jaredhowland.com"),
    .excludeSelectors(["header", "footer", "nav"])
])
print(markdown)
```


## 03 - Wikipedia Article
Tables, domain resolution, and exclude selectors for site chrome.

Code (Examples/03-wikipedia-article/code.swift):

```swift
import HTMLToMarkdown

// Fetch HTML from https://en.wikipedia.org/wiki/Markdown
// let html = try String(contentsOf: URL(string: "https://en.wikipedia.org/wiki/Markdown")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    TablePlugin()
], options: [
    .domain("https://en.wikipedia.org"),
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
```


## 04 - Exclude Navigation
Blog post conversion with navigation, sidebar, and footer excluded.

Code (Examples/04-exclude-navigation/code.swift):

```swift
import HTMLToMarkdown

// Fetch HTML from a blog post URL
// let html = try String(contentsOf: URL(string: "https://example.com/blog/swift-concurrency")!, encoding: .utf8)

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    .excludeSelectors(["nav.site-nav", "aside.sidebar", "footer.site-footer"])
])
print(markdown)
```


## 05 - Custom Plugin
Shows how to write and register a simple plugin (example: uppercase headings).

Code (Examples/05-custom-plugin/code.swift):

```swift
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
                w.writeString("\\n\\n\\(prefix) \\(buf.string.uppercased())")
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
```


## 06 - GFM Features
Demonstrates TaskListItems, Strikethrough, Tables and other GFM features.

Code (Examples/06-gfm-features/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1>GFM Features Demo</h1>

<h2>Task List</h2>
<ul>
  <li><input type=\"checkbox\" checked> Buy groceries</li>
  <li><input type=\"checkbox\"> Write tests</li>
  <li><input type=\"checkbox\" checked> Review PR</li>
</ul>

<h2>Strikethrough</h2>
<p>This is <del>old content</del> and this is new.</p>

<h2>Table</h2>
<table>
  <thead>
    <tr><th>Language</th><th>Stars</th></tr>
  </thead>
  <tbody>
    <tr><td>Swift</td><td>⭐⭐⭐⭐⭐</td></tr>
    <tr><td>Rust</td><td>⭐⭐⭐⭐</td></tr>
  </tbody>
</table>

<h2>Definition List</h2>
<dl>
  <dt>HTML</dt>
  <dd>HyperText Markup Language</dd>
  <dt>CSS</dt>
  <dd>Cascading Style Sheets</dd>
</dl>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    GFMPlugin()
])
print(markdown)
```


## 07 - Atlassian Markdown
Demonstrates Atlassian/Confluence-specific behavior: autolinks, image sizing, attachments, and Confluence macros.

Code (Examples/07-atlassian-markdown/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1>Atlassian Markdown Demo</h1>

<h2>Autolinks</h2>
<p>Visit <a href=\"https://bitbucket.org\">https://bitbucket.org</a> for more information.</p>

<h2>Image Sizing</h2>
<p><img src=\"logo.png\" alt=\"Logo\" width=\"320\" height=\"240\"></p>

<h2>Strikethrough</h2>
<p>This feature is <del>deprecated</del> and should not be used.</p>

<h2>Table</h2>
<table>
  <thead>
    <tr><th>Feature</th><th>Supported</th></tr>
  </thead>
  <tbody>
    <tr><td>Autolinks</td><td>Yes</td></tr>
    <tr><td>Image sizing</td><td>Yes</td></tr>
    <tr><td>Tables</td><td>Yes</td></tr>
    <tr><td>Strikethrough</td><td>Yes</td></tr>
  </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    AtlassianPlugin()
])
print(markdown)
```


## 08 - MultiMarkdown
Demonstrates MultiMarkdown features: sub/sup, definition lists, image attributes, footnotes, and figure captions.

Code (Examples/08-multimarkdown/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1>MultiMarkdown Demo</h1>

<h2>Subscript and Superscript</h2>
<p>Water is H<sub>2</sub>O and Einstein wrote E=mc<sup>2</sup>.</p>

<h2>Definition List</h2>
<dl>
  <dt>MultiMarkdown</dt>
  <dd>An extended version of Markdown with extra features.</dd>
  <dt>CommonMark</dt>
  <dd>A strongly specified, highly compatible implementation of Markdown.</dd>
</dl>

<h2>Image with Attributes</h2>
<figure>
  <img src=\"diagram.png\" alt=\"Architecture Diagram\" width=\"640\" height=\"480\">
  <figcaption>Architecture Diagram</figcaption>
</figure>

<h2>Footnotes</h2>
<p>MultiMarkdown supports footnotes<a href=\"#fn:1\" id=\"fnref:1\" title=\"see footnote\" class=\"footnote\">[1]</a> for academic writing<a href=\"#fn:2\" id=\"fnref:2\" title=\"see footnote\" class=\"footnote\">[2]</a>.</p>

<div class="footnotes">
<hr />
<ol>
<li id=\"fn:1\">Fletcher T. Penney created MultiMarkdown.<a href=\"#fnref:1\" title=\"return to article\" class=\"reversefootnote\"> ↩</a></li>
<li id=\"fn:2\">Footnotes appear at the bottom of the document.<a href=\"#fnref:2\" title=\"return to article\" class=\"reversefootnote\"> ↩</a></li>
</ol>
</div>

<h2>Strikethrough</h2>
<p>This syntax is <del>obsolete</del> now.</p>

<h2>Table</h2>
<table>
  <thead>
    <tr><th>Feature</th><th>Syntax</th></tr>
  </thead>
  <tbody>
    <tr><td>Subscript</td><td>~text~</td></tr>
    <tr><td>Superscript</td><td>^text^</td></tr>
    <tr><td>Footnote ref</td><td>[^1]</td></tr>
  </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    MultiMarkdownPlugin()
])
print(markdown)
```


## 09 - YouTube & Vimeo Embeds
Converts iframe embeds to link or thumbnail representations using YouTubeEmbedPlugin and VimeoEmbedPlugin.

Code (Examples/09-youtube-vimeo/code.swift):

```swift
import HTMLToMarkdown

let html = """
<article>
  <h1>Video Examples</h1>

  <h2>YouTube</h2>
  <iframe width=\"560\" height=\"315\"
    src=\"https://www.youtube.com/embed/dQw4w9WgXcQ\"
    title=\"Rick Astley - Never Gonna Give You Up\"
    frameborder=\"0\" allowfullscreen></iframe>

  <h2>Vimeo</h2>
  <iframe src=\"https://player.vimeo.com/video/148751763\"
    title=\"Big Buck Bunny\"
    width=\"640\" height=\"360\" frameborder=\"0\" allowfullscreen></iframe>
</article>
"""

let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(YouTubeEmbedPlugin())
try conv.Register.plugin(VimeoEmbedPlugin())

let markdown = try conv.convertString(html)
print(markdown)
```


## 10 - Atlassian Confluence
Demonstrates handling of Confluence macros, attachments, and structured code macros.

Code (Examples/10-atlassian-confluence/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1>Atlassian Confluence Demo</h1>

<h2>Autolinks</h2>
<p>Visit <a href=\"https://confluence.atlassian.com\">https://confluence.atlassian.com</a> for docs.</p>

<h2>Code Block</h2>
<ac:structured-macro ac:name=\"code\">
  <ac:parameter ac:name=\"language\">swift</ac:parameter>
  <ac:plain-text-body>let greeting = \"Hello, World!\"
print(greeting)</ac:plain-text-body>
</ac:structured-macro>

<h2>Image Attachment</h2>
<ac:image ac:width=\"400\"><ri:attachment ri:filename=\"screenshot.png\"/></ac:image>

<h2>File Attachment</h2>
<p>Download the report:
<ac:link><ri:attachment ri:filename=\"report.pdf\"/>
<ac:plain-text-link-body>Q4 Report</ac:plain-text-link-body></ac:link></p>

<h2>Image Sizing</h2>
<p><img src=\"logo.png\" alt=\"Logo\" width=\"320\" height=\"240\"></p>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    AtlassianPlugin()
])
print(markdown)
```


## 11 - Markdown Extra
Demonstrates Markdown Extra features: footnotes, abbreviations, definition lists, and header IDs.

Code (Examples/11-markdown-extra/code.swift):

```swift
import HTMLToMarkdown

let html = """
<h1 id=\"markdown-extra-demo\">Markdown Extra Demo</h1>

<h2 id=\"definition-lists\">Definition Lists</h2>
<dl>
  <dt>Markdown Extra</dt>
  <dd>An extension of PHP Markdown implementing features not in standard Markdown.</dd>
  <dt>CommonMark</dt>
  <dd>A strongly specified, highly compatible implementation of Markdown.</dd>
</dl>

<h2 id=\"footnotes\">Footnotes</h2>
<p>Markdown Extra supports footnotes<sup id=\"fnref:1\"><a href=\"#fn:1\" class=\"footnote\">1</a></sup> for academic and technical writing<sup id=\"fnref:2\"><a href=\"#fn:2\" class=\"footnote\">2</a></sup>.</p>

<div class=\"footnotes\">
