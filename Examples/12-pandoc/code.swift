import HTMLToMarkdown

let html = """
<h1 id="pandoc-demo">Pandoc Markdown Demo</h1>

<h2 id="math">LaTeX Math</h2>
<p>Inline math: <span class="math inline">\\(E = mc^2\\)</span></p>
<p>The quadratic formula is <span class="math inline">\\(x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}\\)</span>.</p>

<p>Display math:</p>
<div class="math display">\\[\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}\\]</div>

<h2 id="definition-lists">Definition Lists</h2>
<dl>
  <dt>Pandoc</dt>
  <dd>A universal document converter written in Haskell.</dd>
  <dt>LaTeX</dt>
  <dd>A high-quality typesetting system for scientific and technical documents.</dd>
</dl>

<h2 id="footnotes">Footnotes</h2>
<p>Pandoc was created by John MacFarlane<a href="#fn1" class="footnote-ref"><sup>1</sup></a> at UC Berkeley<a href="#fn2" class="footnote-ref"><sup>2</sup></a>.</p>

<section class="footnotes">
<ol>
<li id="fn1"><p>John MacFarlane is a philosophy professor.<a href="#fnref1" class="footnote-back">↩︎</a></p></li>
<li id="fn2"><p>The University of California, Berkeley.<a href="#fnref2" class="footnote-back">↩︎</a></p></li>
</ol>
</section>

<h2 id="sub-sup">Subscript and Superscript</h2>
<p>Water: H<sub>2</sub>O. Energy: E=mc<sup>2</sup>.</p>

<h2 id="strikethrough">Strikethrough</h2>
<p>This approach is <del>outdated</del> now.</p>

<h2 id="tables">Tables</h2>
<table>
  <thead>
    <tr><th>Feature</th><th>Syntax</th></tr>
  </thead>
  <tbody>
    <tr><td>Inline math</td><td>$...$</td></tr>
    <tr><td>Display math</td><td>$$...$$</td></tr>
    <tr><td>Subscript</td><td>~text~</td></tr>
    <tr><td>Superscript</td><td>^text^</td></tr>
    <tr><td>Header ID</td><td>{#id}</td></tr>
  </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    PandocPlugin()  // Includes math, def lists, footnotes, sub/sup, header IDs
])
print(markdown)
