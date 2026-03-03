import HTMLToMarkdown

let html = """
<h1>Atlassian Markdown Demo</h1>

<h2>Autolinks</h2>
<p>Visit <a href="https://bitbucket.org">https://bitbucket.org</a> for more information.</p>
<p>Or check out <a href="https://atlassian.com">Atlassian</a> for the full suite.</p>

<h2>Image Sizing</h2>
<p><img src="logo.png" alt="Logo" width="320" height="240"></p>
<p><img src="banner.png" alt="Banner" width="800"></p>
<p><img src="icon.png" alt="Icon"></p>

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
    AtlassianPlugin()  // Includes strikethrough, tables, autolinks, image sizing
])
print(markdown)
