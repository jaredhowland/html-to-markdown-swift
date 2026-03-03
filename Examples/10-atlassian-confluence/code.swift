import HTMLToMarkdown

let html = """
<h1>Atlassian Confluence Demo</h1>

<h2>Autolinks</h2>
<p>Visit <a href="https://confluence.atlassian.com">https://confluence.atlassian.com</a> for docs.</p>

<h2>Code Block</h2>
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">swift</ac:parameter>
  <ac:plain-text-body>let greeting = "Hello, World!"
print(greeting)</ac:plain-text-body>
</ac:structured-macro>

<h2>Image Attachment</h2>
<ac:image ac:width="400"><ri:attachment ri:filename="screenshot.png"/></ac:image>

<h2>File Attachment</h2>
<p>Download the report:
<ac:link><ri:attachment ri:filename="report.pdf"/>
<ac:plain-text-link-body>Q4 Report</ac:plain-text-link-body></ac:link></p>

<h2>Image Sizing</h2>
<p><img src="logo.png" alt="Logo" width="320" height="240"></p>
"""

let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    AtlassianPlugin()
])
print(markdown)
