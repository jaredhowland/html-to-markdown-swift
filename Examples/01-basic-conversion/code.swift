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
