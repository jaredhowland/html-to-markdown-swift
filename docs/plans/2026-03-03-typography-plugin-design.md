# Typography Plugin Design

**Date:** 2026-03-03  
**Status:** Approved

## Problem

HTML-to-Markdown conversion produces syntactically correct Markdown but typographically plain text: straight quotes instead of curly quotes, ASCII dashes instead of em/en dashes, plain ellipses instead of the `…` character, and bare URLs that aren't hyperlinked. This plugin addresses all of these.

## Architecture

```
Sources/plugin/typography/
  typography.swift              — TypographyPlugin + QuoteStyle
  typography_smart_quotes.swift — SmartQuotesPlugin
  typography_replacements.swift — ReplacementsPlugin
  typography_linkify.swift      — LinkifyPlugin
  typography_utils.swift        — shared applyOutsideCode() utility
```

### TypographyPlugin

Bundles the three sub-plugins based on init flags:

```swift
public class TypographyPlugin: Plugin {
    public init(
        smartQuotes: Bool = true,
        replacements: Bool = true,
        linkify: Bool = true,
        quoteStyle: QuoteStyle = .english
    )
}
```

Each sub-plugin is also usable standalone.

### QuoteStyle

```swift
public struct QuoteStyle {
    public let openDouble: Character   // e.g. "
    public let closeDouble: Character  // e.g. "
    public let openSingle: Character   // e.g. '
    public let closeSingle: Character  // e.g. '

    public static let english  // " " ' '
    public static let german   // „ " ‚ '
    public static let french   // « » ‹ ›
    public static let swedish  // " " ' '
}
```

## Implementation Strategy: All Three as Post-Renderers

All three plugins operate on the **final Markdown string** via post-renderers. This provides:
- Full context (can see preceding/following characters for smart quote decisions)
- Simple code-avoidance (regex-based code region detection on Markdown is reliable)
- No DOM manipulation needed

### Shared Utility: `applyOutsideCode()`

Splits the Markdown string into **code regions** and **non-code regions**. Applies a transform only to non-code regions and reassembles.

Code regions to skip:
1. Fenced code blocks: ` ```lang\n...\n``` ` or `~~~lang\n...\n~~~`
2. Inline code spans: `` `code` `` (any backtick run length)
3. Markdown link/image URLs: `](url)` and `](url "title")`  ← for SmartQuotes
4. HTML autolinks: `<http://...>` ← for Linkify

## SmartQuotesPlugin

**`<q>` element renderer** (PriorityEarly):
- Renders `<q>text</q>` → `"text"` using configurable open/close double quotes
- Handles nested `<q>` using single quote style for inner level

**Post-renderer** (priority 1100):
Algorithm: scan the Markdown string outside code regions, find `"` and `'` characters, determine open vs. close based on context:

| Quote | Context | Result |
|-------|---------|--------|
| `"` | after whitespace or start of string | open double (`"`) |
| `"` | before whitespace or end of string | close double (`"`) |
| `"` | both sides have text | close double (pair with nearest open) |
| `'` | between two letters (e.g. `don't`) | apostrophe (U+2019) |
| `'` | after whitespace or start | open single (`'`) |
| `'` | before whitespace or end | close single (`'`) |

Stack-based matching ensures properly paired open/close quotes. Unpaired quotes default to close.

## ReplacementsPlugin

**Post-renderer** (priority 1100), applied outside code regions:

| Pattern | Replacement | Notes |
|---------|-------------|-------|
| `(c)` or `(C)` | `©` | |
| `(r)` or `(R)` | `®` | |
| `(tm)` or `(TM)` | `™` | |
| `...` | `…` | but `?...` → `?..`, `!...` → `!..` |
| `---` | `—` (em dash) | must not be part of longer run |
| `--` | `–` (en dash) | surrounded by word/space |
| `+-` | `±` | |
| `????+` | `???` | de-spam |
| `!!!!+` | `!!!` | de-spam |

## LinkifyPlugin

**Post-renderer** (priority 1100), applied outside code regions and outside existing Markdown links:

- Matches bare `http://` and `https://` URLs not already in:
  - `[text](url)` — already a Markdown link
  - `<url>` — already an autolink
  - Code spans/blocks
- Converts to `[url](url)` (most universally supported form)
- URL boundary: stops at whitespace; strips trailing `.`, `,`, `)`, `]` that appear to be punctuation following the URL

## Tests

- `Tests/plugin-typography-smart-quotes_test.swift`
- `Tests/plugin-typography-replacements_test.swift`
- `Tests/plugin-typography-linkify_test.swift`

## Examples

- `Examples/14-typography/code.swift` + `output.md`

## README

Add `TypographyPlugin`, `SmartQuotesPlugin`, `ReplacementsPlugin`, `LinkifyPlugin` to plugin table. Add QuoteStyle usage example.
