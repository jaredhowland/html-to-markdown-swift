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
  <img src="diagram.png" alt="Architecture Diagram" width="640" height="480">
  <figcaption>Architecture Diagram</figcaption>
</figure>

<h2>Footnotes</h2>
<p>MultiMarkdown supports footnotes<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote">[1]</a> for academic writing<a href="#fn:2" id="fnref:2" title="see footnote" class="footnote">[2]</a>.</p>

<div class="footnotes">
<hr />
<ol>
<li id="fn:1">Fletcher T. Penney created MultiMarkdown.<a href="#fnref:1" title="return to article" class="reversefootnote"> ↩</a></li>
<li id="fn:2">Footnotes appear at the bottom of the document.<a href="#fnref:2" title="return to article" class="reversefootnote"> ↩</a></li>
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
    MultiMarkdownPlugin()  // Includes strikethrough, tables, MMD-specific syntax
])
print(markdown)
