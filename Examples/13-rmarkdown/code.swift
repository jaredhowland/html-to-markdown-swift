import HTMLToMarkdown

let html = """
<h1 id="rmarkdown-demo">R Markdown Demo</h1>

<p>R Markdown combines <abbr title="R programming language">R</abbr> code with Markdown text to produce reproducible documents.</p>

<h2 id="math">Mathematical Equations</h2>
<p>Inline: <span class="math inline">\\(\\alpha + \\beta = \\gamma\\)</span></p>
<div class="math display">\\[\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}\\]</div>

<h2 id="figures">Figures with Captions</h2>
<figure>
  <img src="scatter-plot.png" alt="Scatter plot">
  <figcaption>Figure 1: Relationship between variables X and Y (n=150)</figcaption>
</figure>

<figure>
  <img src="histogram.png" alt="Histogram">
  <figcaption>Figure 2: Distribution of response variable</figcaption>
</figure>

<h2 id="tabsets">Tabbed Sections</h2>
<div class="tabset">
  <ul class="nav nav-tabs">
    <li><a href="#tab-summary">Summary</a></li>
    <li><a href="#tab-details">Details</a></li>
    <li><a href="#tab-code">Code</a></li>
  </ul>
  <div class="tab-content">
    <div class="tab-pane" id="tab-summary"><p>Summary statistics and key findings.</p></div>
    <div class="tab-pane" id="tab-details"><p>Detailed methodology and analysis steps.</p></div>
    <div class="tab-pane" id="tab-code"><p>Source code and reproducible scripts.</p></div>
  </div>
</div>

<h2 id="definition-lists">Terminology</h2>
<dl>
  <dt>R Markdown</dt>
  <dd>A format combining R code chunks with Markdown narrative text.</dd>
  <dt>knitr</dt>
  <dd>An R package that executes code chunks and weaves output into documents.</dd>
  <dt>Pandoc</dt>
  <dd>The universal document converter that transforms Markdown to HTML, PDF, and more.</dd>
</dl>

<h2 id="tables">Results Table</h2>
<table>
  <thead>
    <tr><th>Variable</th><th>Mean</th><th>SD</th><th>p-value</th></tr>
  </thead>
  <tbody>
    <tr><td>Height</td><td>170.2</td><td>8.4</td><td>&lt;0.001</td></tr>
    <tr><td>Weight</td><td>68.5</td><td>12.1</td><td>&lt;0.001</td></tr>
    <tr><td>BMI</td><td>23.7</td><td>3.2</td><td>0.043</td></tr>
  </tbody>
</table>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    RMarkdownPlugin()  // Extends PandocPlugin: adds tabsets and figure captions
])
print(markdown)
