# Frontmatter Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a `FrontmatterPlugin` that prepends YAML frontmatter (title, author, description, tags, word count, reading time, etc.) to converted markdown output by extracting `<head>` metadata.

**Architecture:** Two-phase plugin. A pre-renderer at priority 90 (before `BasePlugin` removes `<head>` at priority 100) uses SwiftSoup to extract metadata and stores it in `ctx.setState`. A post-renderer at priority 1100 (after all cleanup at priority 500–1000) reads that state, computes word count and reading time from the final rendered string, builds YAML, and prepends it.

**Tech Stack:** Swift, SwiftSoup, XCTest, Foundation (`ISO8601DateFormatter`, `JSONSerialization`)

---

### Task 1: Plugin stub + failing tests

This task creates the plugin file with just enough structure to compile, then writes all the failing tests. TDD: tests drive the implementation in Tasks 2 and 3.

**Files:**
- Create: `Sources/plugin/frontmatter/frontmatter.swift`
- Create: `Tests/plugin-frontmatter_test.swift`

---

**Step 1: Create stub plugin**

`Sources/plugin/frontmatter/frontmatter.swift`:

```swift
import Foundation
import SwiftSoup

// Metadata extracted from <head> during pre-render phase.
struct FrontmatterMeta {
    var title: String?
    var author: String?
    var description: String?
    var canonicalURL: String?
    var tags: [String] = []
}

private let stateKey = "frontmatter_meta"

public class FrontmatterPlugin: Plugin {
    public var name: String { return "frontmatter" }

    public init() {}

    public func initialize(conv: Converter) throws {
        // Task 2: pre-renderer will go here
        // Task 3: post-renderer will go here
    }
}
```

**Step 2: Create test file with failing tests**

`Tests/plugin-frontmatter_test.swift`:

```swift
import XCTest
@testable import HTMLToMarkdown

// Helper: convert with FrontmatterPlugin registered, optional domain.
private func convert(_ html: String, domain: String = "") throws -> String {
    var opts: [ConverterOption] = []
    if !domain.isEmpty { opts.append(.domain(domain)) }
    return try HTMLToMarkdown.convert(html, plugins: [
        BasePlugin(), CommonmarkPlugin(), FrontmatterPlugin()
    ], options: opts)
}

// Helper: extract YAML frontmatter block (between first and second "---").
private func frontmatter(_ output: String) -> [String: String] {
    let lines = output.components(separatedBy: "\n")
    guard lines.first == "---" else { return [:] }
    var result: [String: String] = [:]
    var i = 1
    while i < lines.count && lines[i] != "---" {
        let line = lines[i]
        if let colonIdx = line.firstIndex(of: ":") {
            let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            result[key] = value
        }
        i += 1
    }
    return result
}

// Helper: extract tags list from output (lines starting with "  - ").
private func tags(_ output: String) -> [String] {
    return output.components(separatedBy: "\n")
        .filter { $0.hasPrefix("  - ") }
        .map { $0.dropFirst(4).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
}

class FrontmatterPluginTests: XCTestCase {

    // MARK: - Output structure

    func testOutputStartsWithFrontmatterBlock() throws {
        let result = try convert("<html><head><title>Test</title></head><body><p>Hello</p></body></html>")
        XCTAssertTrue(result.hasPrefix("---\n"), "Output must start with ---")
    }

    func testFrontmatterClosedWithDashes() throws {
        let result = try convert("<html><head><title>Test</title></head><body><p>Hello</p></body></html>")
        let parts = result.components(separatedBy: "\n---\n")
        XCTAssertGreaterThanOrEqual(parts.count, 2, "Frontmatter must be closed with ---")
    }

    func testMarkdownContentFollowsFrontmatter() throws {
        let result = try convert("<html><head><title>T</title></head><body><p>Hello world</p></body></html>")
        XCTAssertTrue(result.contains("---\n\nHello world"), "Markdown content must follow frontmatter block")
    }

    // MARK: - date_saved always present

    func testDateSavedAlwaysPresent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNotNil(fm["date_saved"], "date_saved must always be present")
    }

    func testDateSavedIsISO8601() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        let dateStr = fm["date_saved"] ?? ""
        let formatter = ISO8601DateFormatter()
        XCTAssertNotNil(formatter.date(from: dateStr), "date_saved must be ISO 8601: \(dateStr)")
    }

    // MARK: - word_count and reading_time

    func testWordCountPresent() throws {
        let result = try convert("<html><head></head><body><p>one two three</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["word_count"], "3")
    }

    func testReadingTimePresentAndValid() throws {
        // 200 words = 1 min, min value is 1
        let words = Array(repeating: "word", count: 200).joined(separator: " ")
        let html = "<html><head></head><body><p>\(words)</p></body></html>"
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["reading_time"], "1 min")
    }

    func testReadingTimeRoundsUp() throws {
        // 201 words → ceil(201/200) = 2 min
        let words = Array(repeating: "word", count: 201).joined(separator: " ")
        let html = "<html><head></head><body><p>\(words)</p></body></html>"
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["reading_time"], "2 min")
    }

    // MARK: - title

    func testTitleFromTitleTag() throws {
        let result = try convert("<html><head><title>My Page</title></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["title"], "My Page")
    }

    func testTitleFallsBackToOgTitle() throws {
        let html = """
        <html><head>
        <meta property="og:title" content="OG Title"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["title"], "OG Title")
    }

    func testTitleOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["title"], "title must be omitted when not found")
    }

    // MARK: - author

    func testAuthorFromMetaTag() throws {
        let html = """
        <html><head>
        <meta name="author" content="Jane Doe"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["author"], "Jane Doe")
    }

    func testAuthorFallsBackToOgAuthor() throws {
        let html = """
        <html><head>
        <meta property="og:author" content="OG Author"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["author"], "OG Author")
    }

    func testAuthorOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["author"])
    }

    // MARK: - description

    func testDescriptionFromMetaTag() throws {
        let html = """
        <html><head>
        <meta name="description" content="A test description."/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["description"], "A test description.")
    }

    func testDescriptionFallsBackToOgDescription() throws {
        let html = """
        <html><head>
        <meta property="og:description" content="OG Desc"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let fm = frontmatter(result)
        XCTAssertEqual(fm["description"], "OG Desc")
    }

    func testDescriptionOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["description"])
    }

    // MARK: - source

    func testSourceFromDomain() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>", domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["source"], "https://example.com")
    }

    func testSourceOmittedWhenDomainNotSet() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["source"])
    }

    // MARK: - url

    func testURLFromCanonicalLink() throws {
        let html = """
        <html><head>
        <link rel="canonical" href="https://example.com/page/"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html, domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["url"], "https://example.com/page/")
    }

    func testURLFallsBackToDomain() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>", domain: "https://example.com")
        let fm = frontmatter(result)
        XCTAssertEqual(fm["url"], "https://example.com")
    }

    func testURLOmittedWhenNeitherPresent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let fm = frontmatter(result)
        XCTAssertNil(fm["url"])
    }

    // MARK: - tags

    func testTagsFromKeywordsMeta() throws {
        let html = """
        <html><head>
        <meta name="keywords" content="swift, ios, macos"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("swift"), "tags must contain 'swift'")
        XCTAssertTrue(t.contains("ios"), "tags must contain 'ios'")
        XCTAssertTrue(t.contains("macos"), "tags must contain 'macos'")
    }

    func testTagsFromArticleTag() throws {
        let html = """
        <html><head>
        <meta property="article:tag" content="programming"/>
        <meta property="article:tag" content="swift"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("programming"))
        XCTAssertTrue(t.contains("swift"))
    }

    func testTagsFromLdJson() throws {
        let json = """
        {"@context":"https://schema.org","@type":"WebPage","keywords":"schema,tags"}
        """
        let html = """
        <html><head>
        <script type="application/ld+json">\(json)</script>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertTrue(t.contains("schema"))
        XCTAssertTrue(t.contains("tags"))
    }

    func testTagsDeduplicatedAcrossSources() throws {
        let html = """
        <html><head>
        <meta name="keywords" content="swift, ios"/>
        <meta property="article:tag" content="swift"/>
        </head><body><p>x</p></body></html>
        """
        let result = try convert(html)
        let t = tags(result)
        XCTAssertEqual(t.filter { $0 == "swift" }.count, 1, "Duplicate tags must be removed")
    }

    func testTagsOmittedWhenAbsent() throws {
        let result = try convert("<html><head></head><body><p>x</p></body></html>")
        let t = tags(result)
        XCTAssertTrue(t.isEmpty, "tags section must be absent when no tags found")
    }
}
```

**Step 3: Verify tests compile and fail**

```bash
cd /path/to/html-to-markdown && swift test --filter FrontmatterPluginTests 2>&1 | tail -20
```

Expected: Tests compile but fail with assertions (stub plugin produces no frontmatter).

---

### Task 2: Pre-renderer — extract metadata from `<head>`

**Files:**
- Modify: `Sources/plugin/frontmatter/frontmatter.swift`

**Step 1: Implement pre-renderer inside `initialize(conv:)`**

Replace the `// Task 2` comment with:

```swift
conv.Register.preRenderer({ ctx, doc in
    var meta = FrontmatterMeta()

    // title: <title> first, then og:title
    if let t = (try? doc.select("title").first()?.text()), !t.isEmpty {
        meta.title = t
    } else if let t = (try? doc.select("meta[property='og:title']").first()?.attr("content")), !t.isEmpty {
        meta.title = t
    }

    // author: meta[name=author] then og:author
    if let a = (try? doc.select("meta[name=author]").first()?.attr("content")), !a.isEmpty {
        meta.author = a
    } else if let a = (try? doc.select("meta[property='og:author']").first()?.attr("content")), !a.isEmpty {
        meta.author = a
    }

    // description: meta[name=description] then og:description
    if let d = (try? doc.select("meta[name=description]").first()?.attr("content")), !d.isEmpty {
        meta.description = d
    } else if let d = (try? doc.select("meta[property='og:description']").first()?.attr("content")), !d.isEmpty {
        meta.description = d
    }

    // url: canonical link then domain
    if let href = (try? doc.select("link[rel=canonical]").first()?.attr("href")), !href.isEmpty {
        meta.canonicalURL = href
    }

    // tags: keywords + article:tag + ld+json
    var tagSet: [String] = []

    if let keywords = (try? doc.select("meta[name=keywords]").first()?.attr("content")), !keywords.isEmpty {
        let parts = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        tagSet.append(contentsOf: parts)
    }

    if let articleTags = try? doc.select("meta[property='article:tag']") {
        for el in articleTags.array() {
            let v = (try? el.attr("content")) ?? ""
            if !v.isEmpty { tagSet.append(v) }
        }
    }

    if let scripts = try? doc.select("script[type='application/ld+json']") {
        for script in scripts.array() {
            guard let jsonText = try? script.html(),
                  let data = jsonText.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if let kw = obj["keywords"] as? String {
                let parts = kw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                tagSet.append(contentsOf: parts)
            } else if let kwArr = obj["keywords"] as? [String] {
                tagSet.append(contentsOf: kwArr.filter { !$0.isEmpty })
            }
        }
    }

    // Deduplicate while preserving order
    var seen = Set<String>()
    meta.tags = tagSet.filter { seen.insert($0).inserted }

    ctx.setState(stateKey, val: meta)
}, priority: PriorityEarly - 10)
```

**Step 2: Run tests to check progress**

```bash
swift test --filter FrontmatterPluginTests 2>&1 | grep -E "passed|failed|error"
```

Expected: Tests related to field extraction start passing; word_count/reading_time/output-structure tests still fail (post-renderer not yet added).

---

### Task 3: Post-renderer — compute word count and prepend frontmatter

**Files:**
- Modify: `Sources/plugin/frontmatter/frontmatter.swift`

**Step 1: Add YAML builder helper at bottom of file**

After the class closing brace, add:

```swift
// MARK: - YAML helpers (internal)

private func yamlString(_ value: String) -> String {
    // Escape double-quote characters inside the value
    let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
}

private func buildFrontmatter(meta: FrontmatterMeta, domain: String, wordCount: Int, readingTime: Int, dateSaved: String) -> String {
    var lines: [String] = ["---"]

    func append(_ key: String, _ value: String?) {
        guard let v = value, !v.isEmpty else { return }
        lines.append("\(key): \(yamlString(v))")
    }

    append("title", meta.title)
    append("author", meta.author)
    append("source", domain.isEmpty ? nil : domain)
    append("url", meta.canonicalURL ?? (domain.isEmpty ? nil : domain))
    lines.append("date_saved: \(yamlString(dateSaved))")
    lines.append("word_count: \(yamlString(String(wordCount)))")
    lines.append("reading_time: \(yamlString("\(readingTime) min"))")
    append("description", meta.description)

    if !meta.tags.isEmpty {
        lines.append("tags:")
        for tag in meta.tags {
            lines.append("  - \(yamlString(tag))")
        }
    }

    lines.append("---")
    return lines.joined(separator: "\n")
}
```

**Step 2: Add post-renderer inside `initialize(conv:)`**

Replace the `// Task 3` comment with:

```swift
conv.Register.postRenderer({ ctx, result in
    let meta: FrontmatterMeta = ctx.getState(stateKey) ?? FrontmatterMeta()

    let words = result.split(whereSeparator: \.isWhitespace).filter { !$0.isEmpty }
    let wordCount = words.count
    let readingTime = max(1, Int(ceil(Double(wordCount) / 200.0)))

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let dateSaved = formatter.string(from: Date())

    let yaml = buildFrontmatter(
        meta: meta,
        domain: ctx.conv.domain,
        wordCount: wordCount,
        readingTime: readingTime,
        dateSaved: dateSaved
    )

    return "\(yaml)\n\n\(result)"
}, priority: PriorityLate + 100)
```

**Step 3: Run all tests**

```bash
swift test 2>&1 | tail -5
```

Expected: All tests pass. Count increases from 170 to 197+ (27 new tests).

**Step 4: Commit**

```bash
git add Sources/plugin/frontmatter/ Tests/plugin-frontmatter_test.swift
git commit -m "feat(frontmatter): add FrontmatterPlugin with YAML frontmatter generation

Extracts title, author, description, url, tags from <head> metadata.
Computes word_count and reading_time from rendered markdown.
Supports og:*, article:tag, and schema.org ld+json tag sources.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 4: Update README

**Files:**
- Modify: `README.md`

**Step 1: Add `FrontmatterPlugin` section under Plugin Documentation**

Find the `#### TablePlugin` section. After the full TablePlugin block (its closing ``` block), add:

```markdown
#### FrontmatterPlugin

Prepends a YAML frontmatter block to the converted markdown output. Extracts metadata from `<head>` (title, author, description, keywords/tags) and computes word count and reading time.

**Frontmatter fields:**

| Field | Source |
|---|---|
| `title` | `<title>` or `og:title` |
| `author` | `meta[name=author]` or `og:author` |
| `source` | `.domain` converter option |
| `url` | `<link rel=canonical>` or `.domain` |
| `date_saved` | Current time (ISO 8601) |
| `word_count` | Counted from rendered markdown |
| `reading_time` | `ceil(words / 200)` min |
| `description` | `meta[name=description]` or `og:description` |
| `tags` | `meta[name=keywords]`, `article:tag`, schema.org ld+json |

Fields are omitted when not found. `date_saved`, `word_count`, and `reading_time` are always present.

**Registration:**

```swift
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    FrontmatterPlugin()
], options: [
    .domain("https://example.com")
])
```

**Example output:**

```yaml
---
title: "My Page Title"
author: "Jane Doe"
source: "https://example.com"
url: "https://example.com/page/"
date_saved: "2026-03-03T20:34:57Z"
word_count: "312"
reading_time: "2 min"
description: "Page description here."
tags:
  - "swift"
  - "ios"
---

{markdown content}
```
```

**Step 2: Add "Writing a Custom Plugin" section**

Find the `## Advanced Usage` section (or add it before `## Error Handling`). Add:

```markdown
### Writing a Custom Plugin

Implement the `Plugin` protocol — provide a `name` and register handlers in `initialize(conv:)`:

```swift
import HTMLToMarkdown

public class MyPlugin: Plugin {
    public var name: String { return "my-plugin" }

    public init() {}

    public func initialize(conv: Converter) throws {
        // Register a renderer for a specific tag
        conv.Register.rendererFor("aside", .block, { ctx, w, node in
            w.writeString("> ")
            ctx.renderChildNodes(w, node)
            return .success
        })

        // Register a text transformer
        conv.Register.textTransformer({ ctx, text in
            return text.replacingOccurrences(of: "foo", with: "bar")
        })

        // Register an escaped character
        conv.Register.escapedChar("@")

        // Register another plugin as a dependency
        try conv.Register.plugin(CommonmarkPlugin())
    }
}

// Use it:
let markdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    MyPlugin()
])
```

Available registration methods on `conv.Register`:

| Method | Purpose |
|---|---|
| `rendererFor(tag, type, handler)` | Handle a specific HTML tag |
| `renderer(handler)` | Catch-all renderer (all tags) |
| `preRenderer(handler)` | Transform DOM before rendering |
| `postRenderer(handler)` | Transform final markdown string |
| `textTransformer(handler)` | Transform text node content |
| `escapedChar(char)` | Mark a character as needing escaping |
| `unEscaper(handler)` | Control when a character is unescaped |
| `tagType(tag, type)` | Override block/inline classification |
| `plugin(plugin)` | Register a sub-plugin dependency |
```

**Step 3: Run tests to confirm README changes didn't break anything**

```bash
swift test 2>&1 | tail -3
```

Expected: All tests still pass.

**Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add FrontmatterPlugin docs and custom plugin writing guide

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Summary

| Task | Output | Tests |
|---|---|---|
| 1 | Stub + failing tests | 27 new failing |
| 2 | Pre-renderer (extract metadata) | Metadata tests pass |
| 3 | Post-renderer (build + prepend YAML) | All 27 pass; total 197 |
| 4 | README update | No new tests |
