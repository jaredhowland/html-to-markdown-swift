# Frontmatter Plugin Design

## Problem

Users want to convert HTML pages into Markdown files with YAML frontmatter — metadata extracted from the HTML `<head>` (title, author, description, keywords) combined with conversion-time data (date saved, word count, reading time) and the configured domain.

## Approach

A `FrontmatterPlugin` that operates in two phases:

1. **Pre-render phase** — scans `<head>` before BasePlugin removes it, stores metadata in `ctx.setState`.
2. **Post-render phase** — reads stored metadata, computes word count and reading time from the rendered markdown, then prepends a YAML frontmatter block.

## Location

`Sources/plugin/frontmatter/frontmatter.swift`

## Fields

| Field | Source | Notes |
|---|---|---|
| `title` | `<title>`, fallback `og:title` | Omit if not found |
| `author` | `<meta name="author">`, fallback `og:author` | Omit if not found |
| `source` | `conv.domain` | Omit if domain not set |
| `url` | `<link rel="canonical">`, fallback `conv.domain` | Omit if not found |
| `date_saved` | `Date()` at conversion time, ISO 8601 | Always present |
| `description` | `<meta name="description">`, fallback `og:description` | Omit if not found |
| `word_count` | Word count of rendered markdown | Always present |
| `reading_time` | `ceil(wordCount / 200)` words/min | Always present |
| `tags` | `meta[name=keywords]` (comma-split) + `meta[property=article:tag]` (multi-value) + `application/ld+json` schema.org keywords | Omit if no tags found |

## Output Format

```
---
title: "Page Title"
author: "Author Name"
source: "https://domain.com"
url: "https://domain.com/page/"
date_saved: "2026-03-03T20:34:57Z"
word_count: "3209"
reading_time: "17 min"
description: "Page description."
tags:
  - "tag one"
  - "tag two"
---

{markdown content}
```

Fields are omitted entirely when their value is empty or not found. `date_saved`, `word_count`, and `reading_time` are always present.

## Architecture

### Priority

- Pre-renderer: `PriorityEarly - 10` (= 90) — runs before BasePlugin removes `<head>` at priority 100
- Post-renderer: `PriorityLate + 100` (= 1100) — runs after all other post-renderers

### State Key

The pre-renderer stores extracted metadata using `ctx.setState` under a key like `"frontmatter_meta"`. The post-renderer reads it with `ctx.getState`.

### Metadata struct (internal)

```swift
struct FrontmatterMeta {
    var title: String?
    var author: String?
    var description: String?
    var canonicalURL: String?
    var tags: [String]
}
```

## Registration

```swift
let conv = Converter(plugins: [
    CommonmarkPlugin(),
    FrontmatterPlugin()
])
```

No separate options struct needed. The domain comes from the `.domain` converter option.

## Tests

`Tests/plugin-frontmatter_test.swift`

- Fields extracted from `<meta>` tags (title, author, description)
- OpenGraph fallbacks
- Tag extraction from keywords, article:tag
- Canonical URL preferred over domain
- Empty fields omitted
- `word_count` and `reading_time` computed correctly
- Output format (starts with `---`, ends with `---\n\n`)

## README Update

Show `FrontmatterPlugin` as an example of registering a custom plugin. Demonstrate the pattern of using `conv.Register.*` inside `initialize(conv:)`.
