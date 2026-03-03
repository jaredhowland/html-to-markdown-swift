import HTMLToMarkdown

let html = """
<h1>GFM Features Demo</h1>

<h2>Task List</h2>
<ul>
  <li><input type="checkbox" checked> Buy groceries</li>
  <li><input type="checkbox"> Write tests</li>
  <li><input type="checkbox" checked> Review PR</li>
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
