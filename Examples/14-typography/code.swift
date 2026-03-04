import HTMLToMarkdown

// MARK: - Example 14: TypographyPlugin
// Demonstrates smart quotes, typographic replacements, and URL linkification.

let html = """
<h1>Typography Demo</h1>

<h2>Smart Quotes</h2>
<p>She said "Hello, world!" and he replied "That's wonderful!"</p>
<p>The book 'A Brief History of Time' changed my perspective.</p>
<p>It's a beautiful day, don't you think?</p>
<p>She said <q>This is a semantic quote element.</q></p>

<h2>Typographic Replacements</h2>
<p>(c) 2024 Acme Corporation. All rights reserved.</p>
<p>Acme(r) and WidgetPro(tm) are registered marks.</p>
<p>Wait... something happened---everything changed.</p>
<p>Temperature: 37+-2 degrees.</p>
<p>Paris--London--Tokyo route.</p>

<h2>Linkify</h2>
<p>Find the documentation at https://example.com/docs.</p>
<p>Source code: https://github.com/example/repo</p>
<p>Already linked: <a href="https://example.com">Visit Example</a></p>

<h2>Code Blocks Unaffected</h2>
<pre><code>let greeting = "Hello, World!"  -- not an em dash
let url = "https://raw-url.com"  -- not linkified
// (c) not a copyright symbol
</code></pre>

<h2>German Quotes</h2>
<p>Er sagte "Guten Tag" und sie antwortete "Danke schön".</p>
"""

// Default: English smart quotes + all replacements + linkify
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    TypographyPlugin()
])
print(markdown)

print("\n\n---\n\n// German quote style:\n")
let german = try HTMLToMarkdown.convert("<p>Er sagte \"Guten Tag\" und sie antwortete \"Danke schön\".</p>", plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    TypographyPlugin(quoteStyle: .german)
])
print(german)
