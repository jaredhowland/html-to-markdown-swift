# Character Escaping

When converting HTML to Markdown, certain characters in text content have special meaning in Markdown (like `*`, `-`, `#`). The converter automatically escapes these characters **only when they would trigger unintended Markdown formatting**.

## Default Behavior (Smart Escaping)

By default, characters are escaped only when context requires it:

```swift
// "- not a list" would render as a bullet list item in Markdown
// The converter escapes the leading dash:
let html = "<p>- not a list item</p>"
let markdown = try HTMLToMarkdown.convert(html)
// Output: \- not a list item

// A dash in the middle of text is NOT escaped:
let html2 = "<p>well-known</p>"
let markdown2 = try HTMLToMarkdown.convert(html2)
// Output: well-known
```

## When Characters Are Escaped

| Pattern | Reason | Example input → output |
|---------|--------|------------------------|
| `# ` at start of line | ATX heading | `# text` → `\# text` |
| `- `, `* `, `+ ` at start of line | Unordered list | `- item` → `\- item` |
| `1. ` at start of line | Ordered list | `1. item` → `1\. item` |
| `*word` or `_word` (no trailing space) | Emphasis | `*word*` → `\*word\*` |
| All-`=` or all-`-` line after content | Setext heading | `===` line after text |

## When Characters Are NOT Escaped

- `*` followed by a space: `price * discount` stays as-is (not emphasis)
- `#` in the middle of a line: `#hashtag` stays as-is
- Characters inside code spans or code blocks: never escaped

## Disabling Escaping

To disable all escaping:

```swift
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.disabled)])
```

With escaping disabled, text content is passed through as-is (only `<` and `>` are converted to HTML entities).

## See Also

- [CommonMark Specification](https://spec.commonmark.org/)
- [GitHub Flavored Markdown](https://github.github.com/gfm/)
