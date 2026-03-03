import HTMLToMarkdown

let html = """
<article>
  <h1>Video Examples</h1>

  <h2>YouTube</h2>
  <iframe width="560" height="315"
    src="https://www.youtube.com/embed/dQw4w9WgXcQ"
    title="Rick Astley - Never Gonna Give You Up"
    frameborder="0" allowfullscreen></iframe>

  <h2>Vimeo</h2>
  <iframe src="https://player.vimeo.com/video/148751763"
    title="Big Buck Bunny"
    width="640" height="360" frameborder="0" allowfullscreen></iframe>
</article>
"""

let conv = Converter()
try conv.Register.plugin(BasePlugin())
try conv.Register.plugin(CommonmarkPlugin())
try conv.Register.plugin(YouTubeEmbedPlugin())
try conv.Register.plugin(VimeoEmbedPlugin())

let markdown = try conv.convertString(html)
print(markdown)
