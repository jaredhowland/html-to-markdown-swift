# Character Escaping in HTML to Markdown

## Overview

When converting HTML to Markdown, certain characters have special meaning in Markdown syntax (like `*`, `_`, `[`, etc.). The converter can automatically escape these characters to ensure the Markdown renders correctly.

## Escape Modes

### Smart Escaping (Default)

```swift
.escapeMode(.smart)  // or omitted as it's the default
```

In smart escape mode, special characters are escaped only when necessary to prevent unintended Markdown formatting.

**Example:**
```swift
let html = "<p>This costs $5 * 2 = $10</p>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.smart)])
// Output: This costs $5 \* 2 = $10
// Only the asterisk is escaped because it could trigger emphasis formatting
```

### Disabled Escaping

```swift
.escapeMode(.disabled)
```

All special characters are left as-is, which may result in unintended formatting in some cases.

**Example:**
```swift
let html = "<p>This costs $5 * 2 = $10</p>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.disabled)])
// Output: This costs $5 * 2 = $10
// No escaping applied; the asterisk might be interpreted as emphasis
```

## Special Characters

The following characters may be escaped depending on the escape mode and context:

| Character | Markdown Function |
|-----------|------------------|
| `\` | Escape character |
| `` ` `` | Code delimiter |
| `*` | Emphasis, strong |
| `_` | Emphasis, strong |
| `{}` | Used in some markdown extensions |
| `[]` | Links and references |
| `()` | URLs in links |
| `#` | Headings |
| `+` | Lists |
| `-` | Horizontal rules, lists |
| `.` | Lists |
| `!` | Images |

## When Characters Are Escaped

The smart escape mode traces the context of text to determine when escaping is necessary:

- Text at the beginning of a line followed by special characters that would form a list item
- Asterisks or underscores that could be interpreted as emphasis/strong
- Hashes at the beginning of a line (could be interpreted as headings)
- Characters within link text or URLs

## Examples

### Example 1: Emphasis Protection

```swift
let html = "<p>Use *this* syntax for emphasis</p>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.smart)])
// Output: Use \*this\* syntax for emphasis
// The asterisks are escaped to prevent them from being interpreted as emphasis
```

### Example 2: List Item Protection

```swift
let html = "<p>* This looks like a list item but isn't</p>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.smart)])
// Output: \* This looks like a list item but isn't
// The asterisk is escaped to prevent list interpretation
```

### Example 3: URL with Special Characters

```swift
let html = "<a href=\"https://example.com/?foo=bar&baz=qux\">Link</a>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.smart)])
// Output: [Link](https://example.com/?foo=bar&baz=qux)
// No escaping in URLs, they're already properly formatted
```

## Backslash Handling

Backslashes in the original HTML are preserved in the Markdown output. When smart escaping is enabled, additional backslashes may be added before special characters.

```swift
let html = "<p>Path: C:\\Users\\name</p>"
let markdown = try HTMLToMarkdown.convert(html, options: [.escapeMode(.smart)])
// Output: Path: C:\\Users\\name
// Backslashes are preserved
```

## Security Implications

This library does NOT sanitize untrusted content. When converting potentially malicious HTML:

1. Use an HTML sanitizer (like [SwiftSoup](https://github.com/scinfu/SwiftSoup) with content filtering) before conversion
2. Apply markdown sanitization after conversion if rendering in a browser
3. Be aware that the escaped Markdown still represents the original content

Example of proper usage with untrusted content:

```swift
import HTMLToMarkdown

// IMPORTANT: Sanitize HTML before conversion
// (Use appropriate HTML sanitization library for your use case)
let unsafeHTML = userProvidedHTML  // Could contain malicious content
let sanitizedHTML = sanitize(unsafeHTML)  // Use a proper sanitizer

let markdown = try HTMLToMarkdown.convert(sanitizedHTML)
// Now safe to use the markdown
```

## Compatibility

The escaping behavior aims to match the original Go html-to-markdown library's approach while following Swift string conventions.

## See Also

- [CommonMark Specification](https://spec.commonmark.org/)
- [GitHub Flavored Markdown](https://github.github.com/gfm/)
