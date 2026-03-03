# Hello, World!

This is a **basic** HTML-to-Markdown conversion example.

It supports:

- **Bold** and *italic* text
- [Links](https://example.com)
- Lists (ordered and unordered)
- Code: `let x = 42`

## Code Block

```swift

let converter = HTMLToMarkdown.createConverter(
    plugins: [BasePlugin(), CommonmarkPlugin()]
)
let markdown = try converter.convertString(html)
  
```

> Simple things should be simple, complex things should be possible.

1. First item
2. Second item
3. Third item
