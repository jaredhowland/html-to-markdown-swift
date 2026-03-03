import HTMLToMarkdown

let html = """
<h1 id="markdown-extra-demo">Markdown Extra Demo</h1>

<h2 id="definition-lists">Definition Lists</h2>
<dl>
  <dt>Markdown Extra</dt>
  <dd>An extension of PHP Markdown implementing features not in standard Markdown.</dd>
  <dt>CommonMark</dt>
  <dd>A strongly specified, highly compatible implementation of Markdown.</dd>
</dl>

<h2 id="footnotes">Footnotes</h2>
<p>Markdown Extra supports footnotes<sup id="fnref:1"><a href="#fn:1" class="footnote">1</a></sup> for academic and technical writing<sup id="fnref:2"><a href="#fn:2" class="footnote">2</a></sup>.</p>

<div class="footnotes">
<hr />
<ol>
<li id="fn:1">Michel Fortin created Markdown Extra as a PHP Markdown extension.<a href="#fnref:1" class="reversefootnote"> ↩</a></li>
<li id="fn:2">Footnotes appear at the end of the document as definitions.<a href="#fnref:2" class="reversefootnote"> ↩</a></li>
</ol>
</div>

<h2 id="abbreviations">Abbreviations</h2>
<p>Use <abbr title="HyperText Markup Language">HTML</abbr> to structure your content.
<abbr title="Cascading Style Sheets">CSS</abbr> handles presentation.
Together <abbr title="HyperText Markup Language">HTML</abbr> and <abbr title="Cascading Style Sheets">CSS</abbr> power the modern web.</p>

<h2 id="strikethrough">Strikethrough</h2>
<p>This feature is <del>deprecated</del> and has been replaced.</p>

<h2 id="tables">Tables</h2>
<table>
  <thead>
    <tr><th>Feature</th><th>Syntax</th><th>Description</th></tr>
  </thead>
  <tbody>
    <tr><td>Definition list</td><td>term\\n:   def</td><td>Term and definition pairs</td></tr>
    <tr><td>Footnote ref</td><td>[^1]</td><td>Numbered footnote reference</td></tr>
    <tr><td>Abbreviation</td><td>*[Abbr]: Full</td><td>Abbreviation reference list</td></tr>
    <tr><td>Header ID</td><td>{#custom-id}</td><td>Anchor for headings</td></tr>
  </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    MarkdownExtraPlugin()  // Includes strikethrough, tables, ME-specific syntax
])
print(markdown)
