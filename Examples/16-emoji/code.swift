import HTMLToMarkdown

// MARK: - Example 16: EmojiPlugin
// Demonstrates converting GitHub emoji <img> elements and Unicode emoji characters
// using EmojiPlugin with .shortcode (default) and .unicode output styles.

let html = """
<h1>Emoji Demo</h1>

<h2>GitHub Emoji Images</h2>
<p>I feel <img class="emoji" src="https://github.githubassets.com/images/icons/emoji/unicode/1f604.png" alt=":smile:"> today!</p>
<p>Great work! <img class="emoji" src="https://github.githubassets.com/images/icons/emoji/unicode/1f44d.png" alt=":+1:"></p>
<p>Ship it! <img class="emoji" src="https://github.githubassets.com/images/icons/emoji/unicode/1f680.png" alt=":rocket:"></p>

<h2>Unicode Emoji in Text</h2>
<p>I ❤️ open source.</p>
<p>Celebration time 🎉🎊</p>

<h2>Regular Images (Unaffected)</h2>
<p>Logo: <img src="logo.png" alt="Company Logo"></p>

<h2>Emoji in Code (Unaffected)</h2>
<pre><code>let mood = "😄"  // not converted</code></pre>
"""

// Shortcode mode (default): converts emoji to :shortcode: syntax
print("// Shortcode mode (default):\n")
let shortcodeMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    EmojiPlugin()
])
print(shortcodeMarkdown)

print("\n\n---\n\n// Unicode mode: keeps/converts emoji as Unicode characters:\n")
let unicodeMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    EmojiPlugin(outputStyle: .unicode)
])
print(unicodeMarkdown)
