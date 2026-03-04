# Reference Links & Emoji Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Add `ReferenceLinkPlugin` (deferred numbered reference links at document bottom) and `EmojiPlugin` (GFM `:shortcode:` emoji support with Unicode emoji conversion).

**Architecture:** ReferenceLinkPlugin overrides `<a>` and `<img>` renderers at PriorityEarly, accumulates links via `ctx.updateState`, then emits `[N]: url "title"` block in a post-renderer. EmojiPlugin uses a text transformer for Unicode→shortcode and a custom `<img class="emoji">` renderer. Both are standalone plugins. CommonmarkPlugin is unchanged.

**Tech Stack:** Swift 5.9, SPM, SwiftSoup, XCTest. Pattern reference: `Sources/plugin/markdownextra/me_render_abbreviations.swift` (inline collection + post-render append). Test pattern: existing `Tests/plugin-*_test.swift` files.

---

## Reference: Key Codebase Patterns

**Plugin pattern:**
```swift
public class XPlugin: Plugin {
    public var name: String { return "x" }
    public init() {}
    public func initialize(conv: Converter) throws { ... }
}
```

**Collecting during render, emitting in post-render** (see `me_render_abbreviations.swift`):
```swift
// In renderer: collect
ctx.updateState("key") { (existing: [Item]?) -> [Item] in
    var list = existing ?? []
    list.append(item)
    return list
}

// In post-renderer:
let items: [Item]? = ctx.getState("key")
```

**Priority constants:** `PriorityEarly = 100`, `PriorityStandard = 500`, `PriorityLate = 1000`

**Test boilerplate:**
```swift
private func convert(_ html: String) throws -> String {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(ReferenceLinkPlugin())
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}
```

**Text transformer signature:** `(Context, String) -> String` — runs on every `#text` node content, NOT on `<code>` or `<pre>` content (those use `extractRawText()`).

**Golden files structure:**
- Input: `Tests/data/plugin/commonmark/testdata/GoldenFiles/NAME.in.html`
- Output: `Tests/data/plugin/commonmark/testdata/GoldenFiles/NAME.out.md`
- Add test to: `Tests/swift-golden_test.swift`

---

## Task 1: ReferenceLinkPlugin — Core

**Files:**
- Create: `Sources/plugin/referencelinks/referencelinks.swift`
- Create: `Sources/plugin/referencelinks/referencelinks_render_links.swift`
- Create: `Sources/plugin/referencelinks/referencelinks_render_images.swift`
- Create: `Tests/plugin-reference-links_test.swift`

**Step 1: Write failing tests first**

`Tests/plugin-reference-links_test.swift`:
```swift
import XCTest
@testable import HTMLToMarkdown

private func makeConverter(inline: Bool = false) throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(ReferenceLinkPlugin(inlineLinks: inline))
    return conv
}

private func convert(_ html: String, inline: Bool = false) throws -> String {
    let conv = try makeConverter(inline: inline)
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class ReferenceLinkPluginTests: XCTestCase {

    func testBasicReferenceLink() throws {
        let result = try convert("<p><a href=\"https://example.com\">Visit here</a></p>")
        XCTAssertTrue(result.contains("[Visit here][1]"), "Expected reference inline in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com"), "Expected reference def in: \(result)")
        XCTAssertFalse(result.contains("[Visit here](https://example.com)"), "Should not be inline: \(result)")
    }

    func testLinkWithTitle() throws {
        let result = try convert("<p><a href=\"https://example.com\" title=\"Example Site\">Visit</a></p>")
        XCTAssertTrue(result.contains("[Visit][1]"), "Expected reference inline in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com \"Example Site\""), "Expected title in ref def: \(result)")
    }

    func testReferenceAtBottomAfterContent() throws {
        let result = try convert("<p><a href=\"https://a.com\">A</a></p><p>Some text.</p>")
        let linkDefRange = result.range(of: "[1]: https://a.com")!
        let textRange = result.range(of: "Some text.")!
        XCTAssertTrue(linkDefRange.lowerBound > textRange.lowerBound, "Ref def must be after body text in: \(result)")
    }

    func testDeduplication() throws {
        let result = try convert("<p><a href=\"https://example.com\">First</a> and <a href=\"https://example.com\">Second</a></p>")
        // Both should use [1]
        XCTAssertTrue(result.contains("[First][1]"), "First link: \(result)")
        XCTAssertTrue(result.contains("[Second][1]"), "Second link (same URL): \(result)")
        // Only one definition
        let count = result.components(separatedBy: "[1]: https://example.com").count - 1
        XCTAssertEqual(count, 1, "Should have exactly one definition: \(result)")
    }

    func testMultipleLinksNumbered() throws {
        let result = try convert("<p><a href=\"https://a.com\">A</a> and <a href=\"https://b.com\">B</a></p>")
        XCTAssertTrue(result.contains("[A][1]"), "First link: \(result)")
        XCTAssertTrue(result.contains("[B][2]"), "Second link: \(result)")
        XCTAssertTrue(result.contains("[1]: https://a.com"), "First def: \(result)")
        XCTAssertTrue(result.contains("[2]: https://b.com"), "Second def: \(result)")
    }

    func testImageReferenceStyle() throws {
        let result = try convert("<p><img src=\"https://example.com/img.png\" alt=\"My Image\"></p>")
        XCTAssertTrue(result.contains("![My Image][1]"), "Expected image ref syntax in: \(result)")
        XCTAssertTrue(result.contains("[1]: https://example.com/img.png"), "Expected image ref def in: \(result)")
    }

    func testInlineLinkOption() throws {
        let result = try convert("<p><a href=\"https://example.com\">Visit</a></p>", inline: true)
        XCTAssertTrue(result.contains("[Visit](https://example.com)"), "Expected inline link: \(result)")
        XCTAssertFalse(result.contains("[1]:"), "Should not have ref defs when inline: \(result)")
    }

    func testEmptyLinkContent() throws {
        // Empty links pass through CommonmarkPlugin behavior
        let result = try convert("<p><a href=\"https://example.com\"></a></p>")
        // Should not crash; either renders empty ref or passes through
        XCTAssertNotNil(result)
    }

    func testBlankLineSeparation() throws {
        // Reference block must be preceded by blank line (two newlines from content)
        let result = try convert("<p>Text. <a href=\"https://example.com\">Link</a></p>")
        // Find [1]: and check there are 2 newlines before it
        if let range = result.range(of: "[1]:") {
            let before = String(result[result.startIndex..<range.lowerBound])
            XCTAssertTrue(before.hasSuffix("\n\n"), "Expected blank line before ref block in: \(result)")
        } else {
            XCTFail("No reference definition found in: \(result)")
        }
    }
}
```

**Step 2: Run to confirm compile failure**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test --filter ReferenceLinkPluginTests 2>&1 | tail -5
```
Expected: compile error — `ReferenceLinkPlugin` not found.

**Step 3: Create the main plugin file**

`Sources/plugin/referencelinks/referencelinks.swift`:
```swift
import Foundation
import SwiftSoup

let refLinksKey = "reference_links"

struct RefLink: Equatable {
    let url: String
    let title: String
}

public class ReferenceLinkPlugin: Plugin {
    public var name: String { return "reference-links" }
    let inlineLinks: Bool

    public init(inlineLinks: Bool = false) {
        self.inlineLinks = inlineLinks
    }

    public func initialize(conv: Converter) throws {
        if inlineLinks { return }  // Do nothing; CommonmarkPlugin renders inline by default
        registerLinkRenderer(conv: conv)
        registerImageRenderer(conv: conv)
        registerPostRenderer(conv: conv)
    }

    func nextRefNumber(for url: String, ctx: Context) -> Int {
        var links: [RefLink] = ctx.getState(refLinksKey) ?? []
        // Check if URL already has a number
        for (i, link) in links.enumerated() {
            if link.url == url { return i + 1 }
        }
        // New URL: assign next number
        let num = links.count + 1
        links.append(RefLink(url: url, title: ""))
        ctx.setState(refLinksKey, val: links)
        return num
    }
}
```

**Step 4: Create link renderer**

`Sources/plugin/referencelinks/referencelinks_render_links.swift`:
```swift
import Foundation
import SwiftSoup

extension ReferenceLinkPlugin {
    func registerLinkRenderer(conv: Converter) {
        conv.Register.rendererFor("a", .inline, { [weak self] ctx, w, n in
            guard let self = self else { return .tryNext }
            guard let element = n as? Element else { return .tryNext }

            let rawHref = (try? element.attr("href")) ?? ""
            let href = defaultAssembleAbsoluteURL(rawHref, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)

            // Pass through to next handler for special link types (footnote refs etc.)
            // They check for specific classes — if this element has class="footnote-ref" etc.,
            // PriorityEarly handlers for those would have fired already with their own check.
            // Our check: skip empty hrefs (let CommonmarkPlugin handle them as configured).
            if href.isEmpty { return .tryNext }

            let rawTitle = ((try? element.attr("title")) ?? "")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            let buf = StringWriter()
            ctx.renderChildNodes(buf, n)
            let content = buf.string

            let leftPad = String(content.prefix(while: { $0.isWhitespace }))
            let innerRaw = String(content.drop(while: { $0.isWhitespace }))
            let rightPad = String(innerRaw.reversed().prefix(while: { $0.isWhitespace }).reversed())
            let inner = String(innerRaw.dropLast(rightPad.count))

            if inner.isEmpty { return .tryNext }

            // Collect link into state
            var links: [RefLink] = ctx.getState(refLinksKey) ?? []
            let idx: Int
            if let existing = links.firstIndex(where: { $0.url == href }) {
                idx = existing + 1
            } else {
                links.append(RefLink(url: href, title: rawTitle))
                idx = links.count
                ctx.setState(refLinksKey, val: links)
            }

            w.writeString("\(leftPad)[\(inner)][\(idx)]\(rightPad)")
            return .success
        }, priority: PriorityEarly)
    }
}
```

**Step 5: Create image renderer**

`Sources/plugin/referencelinks/referencelinks_render_images.swift`:
```swift
import Foundation
import SwiftSoup

extension ReferenceLinkPlugin {
    func registerImageRenderer(conv: Converter) {
        conv.Register.rendererFor("img", .inline, { [weak self] ctx, w, n in
            guard let self = self else { return .tryNext }
            guard let element = n as? Element else { return .tryNext }

            let rawSrc = (try? element.attr("src")) ?? ""
            let src = defaultAssembleAbsoluteURL(rawSrc, domain: ctx.conv.domain.isEmpty ? nil : ctx.conv.domain)
            if src.isEmpty { return .tryNext }

            // Skip emoji images — they have class="emoji"
            if element.hasClass("emoji") { return .tryNext }

            let rawAlt = ((try? element.attr("alt")) ?? "").replacingOccurrences(of: "\n", with: " ")
            let rawTitle = ((try? element.attr("title")) ?? "")
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\r", with: " ")

            var links: [RefLink] = ctx.getState(refLinksKey) ?? []
            let idx: Int
            if let existing = links.firstIndex(where: { $0.url == src }) {
                idx = existing + 1
            } else {
                links.append(RefLink(url: src, title: rawTitle))
                idx = links.count
                ctx.setState(refLinksKey, val: links)
            }

            w.writeString("![\(rawAlt)][\(idx)]")
            return .success
        }, priority: PriorityEarly)
    }
}
```

**Step 6: Add post-renderer back to main file**

Add this method to `referencelinks.swift` (or add it to `initialize` directly):
```swift
// Add to initialize(conv:) after the other register calls:
func registerPostRenderer(conv: Converter) {
    conv.Register.postRenderer({ ctx, result in
        let links: [RefLink]? = ctx.getState(refLinksKey)
        guard let items = links, !items.isEmpty else { return result }

        var output = result + "\n"
        for (i, link) in items.enumerated() {
            let num = i + 1
            if link.title.isEmpty {
                output += "\n[\(num)]: \(link.url)"
            } else {
                // Use same title quoting as CommonmarkPlugin.formatLinkTitle
                let title = link.title
                let hasDouble = title.contains("\"")
                let hasSingle = title.contains("'")
                let quotedTitle: String
                if hasDouble && hasSingle {
                    quotedTitle = "\"" + title.replacingOccurrences(of: "\"", with: "\\\"") + "\""
                } else if hasDouble {
                    quotedTitle = "'\(title)'"
                } else {
                    quotedTitle = "\"\(title)\""
                }
                output += "\n[\(num)]: \(link.url) \(quotedTitle)"
            }
        }
        return output
    }, priority: 1055)
}
```

**Step 7: Run tests — all must pass**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test --filter ReferenceLinkPluginTests 2>&1 | tail -25
```

Debug notes:
- `testBlankLineSeparation`: BasePlugin's post-renderer trims consecutive newlines and calls `trimConsecutiveNewlines`. The ref block post-renderer runs at 1055 (AFTER BasePlugin's 500). But BasePlugin's trim post-renderer runs at PriorityStandard (500). So our post-renderer runs AFTER trim. The result from BasePlugin is already trimmed; we add `\n` + `\n[1]: url`. That gives one blank line. Check: `result + "\n"` then `"\n[1]: url"` = `result + "\n\n[1]: url"`. That's two newlines = one blank line. ✓

**Step 8: Run all tests for regressions**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test 2>&1 | tail -5
```

**Step 9: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Sources/plugin/referencelinks/ Tests/plugin-reference-links_test.swift && git commit -m "feat: add ReferenceLinkPlugin with numbered reference-style links

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 2: Reference Links — Golden Files

**Files:**
- Create: `Tests/data/plugin/commonmark/testdata/GoldenFiles/link-reference.in.html`
- Create: `Tests/data/plugin/commonmark/testdata/GoldenFiles/link-reference.out.md`
- Create: `Tests/data/plugin/commonmark/testdata/GoldenFiles/image-reference.in.html`
- Create: `Tests/data/plugin/commonmark/testdata/GoldenFiles/image-reference.out.md`
- Modify: `Tests/swift-golden_test.swift` — add two new test methods

**Step 1: Create link golden file input**

`Tests/data/plugin/commonmark/testdata/GoldenFiles/link-reference.in.html`:
```html
<p><a href="https://example.com">Simple link</a></p>

<p><a href="https://example.com" title="Example Site">Link with title</a></p>

<p><a href="https://a.com">First</a> and <a href="https://b.com">Second</a></p>

<p>Same URL: <a href="https://a.com">Again A</a></p>

<p><a href="">Empty href</a></p>

<p>No links here.</p>
```

**Step 2: Manually trace the expected output**

Run a temporary test to capture actual output, then write it to the `.out.md` file. Use this approach:
- Add temporary test that prints output to confirm expected behavior
- Write that exact output to the golden file

Alternatively, compute manually:
1. `[Simple link][1]` + `[1]: https://example.com`
2. `[Link with title][2]` + `[2]: https://example.com "Example Site"`  
   Wait — dedup! "Simple link" uses `https://example.com` first → gets [1]. "Link with title" has SAME URL `https://example.com` → reuses [1]. So `[Link with title][1]` and only one `[1]: https://example.com "Example Site"` — but wait, the title is different.  
   **Important**: dedup is by URL only. First encounter defines the title. "Simple link" (no title) comes first → `[1]: https://example.com`. "Link with title" → same URL, same number [1], title ignored.  
   Hmm, this is a design question. Let me reconsider: if same URL has different titles, what do we do? The design says "same URL → same number". The first-encountered title wins. This could be surprising but is consistent.  
   For the golden file: don't use same URL with different titles in the golden input. Adjust input accordingly.

**Revised golden input** `link-reference.in.html`:
```html
<p><a href="https://a.com">Link A</a></p>

<p><a href="https://b.com" title="Site B">Link B with title</a></p>

<p><a href="https://c.com">Third</a> and <a href="https://c.com">Also C</a></p>

<p><a href="">Empty href link</a></p>

<p>No links here.</p>
```

**Expected output** `link-reference.out.md`:
```markdown
[Link A][1]

[Link B with title][2]

[Third][3] and [Also C][3]

[Empty href link]()

No links here.

[1]: https://a.com
[2]: https://b.com "Site B"
[3]: https://c.com
```

**IMPORTANT**: Run the converter programmatically to get the exact output — don't guess whitespace. Write a temporary test:
```swift
func testPrintReferenceLinkOutput() throws {
    let html = """
    <p><a href="https://a.com">Link A</a></p>
    <p><a href="https://b.com" title="Site B">Link B with title</a></p>
    <p><a href="https://c.com">Third</a> and <a href="https://c.com">Also C</a></p>
    <p><a href="">Empty href link</a></p>
    <p>No links here.</p>
    """
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(ReferenceLinkPlugin())
    let result = try conv.convertString(html)
    print("=== OUTPUT ===\n\(result)\n=== END ===")
}
```
Run: `swift test --filter testPrintReferenceLinkOutput`
Use actual output to write the `.out.md` file, then remove this temporary test.

**Step 3: Create image golden files similarly**

`image-reference.in.html`:
```html
<p><img src="https://example.com/photo.jpg" alt="Photo"></p>

<p><img src="https://example.com/banner.png" alt="Banner" title="Site Banner"></p>

<p>Two same image: <img src="https://example.com/icon.svg" alt="Icon"> and <img src="https://example.com/icon.svg" alt="Icon2"></p>

<p>Link and image same URL: <a href="https://example.com/photo.jpg">See photo</a></p>
```

Use same print-and-capture approach to write `image-reference.out.md`.

**Step 4: Add golden file tests to swift-golden_test.swift**

Find the last `testCommonmark*` method in `Tests/swift-golden_test.swift` and add after it:

```swift
func testCommonmarkLinkReference() {
    let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/link-reference"
    let conv = Converter()
    try? conv.Register.plugin(BasePlugin())
    try? conv.Register.plugin(CommonmarkPlugin())
    try? conv.Register.plugin(ReferenceLinkPlugin())
    runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                  plugins: [BasePlugin(), CommonmarkPlugin(), ReferenceLinkPlugin()],
                  description: "commonmark/link-reference")
}

func testCommonmarkImageReference() {
    let base = "\(goldenBase)/plugin/commonmark/testdata/GoldenFiles/image-reference"
    runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                  plugins: [BasePlugin(), CommonmarkPlugin(), ReferenceLinkPlugin()],
                  description: "commonmark/image-reference")
}
```

Check `runGoldenFile` signature in `swift-golden_test.swift` — it takes `plugins: [Plugin]`. Use that exact signature.

**Step 5: Run golden file tests**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test --filter "testCommonmarkLinkReference\|testCommonmarkImageReference" 2>&1 | tail -20
```

Expected: pass.

**Step 6: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Tests/data/plugin/commonmark/testdata/GoldenFiles/link-reference.* Tests/data/plugin/commonmark/testdata/GoldenFiles/image-reference.* Tests/swift-golden_test.swift && git commit -m "test: add golden files for reference-style links and images

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 3: Example 15 — Reference Links

**Files:**
- Create: `Examples/15-reference-links/code.swift`
- Create: `Examples/15-reference-links/output-reference.md`
- Create: `Examples/15-reference-links/output-inline.md`

**Step 1: Look at an existing example for the code structure**

```bash
cat /Users/wgu/Code/xcode/html-to-markdown/Examples/01-basic-conversion/code.swift
```

**Step 2: Create code.swift**

`Examples/15-reference-links/code.swift`:
```swift
import HTMLToMarkdown

let html = """
<h1>Article with Links</h1>

<p>
  Learn about <a href="https://swift.org">Swift</a>,
  <a href="https://github.com">GitHub</a>, and
  <a href="https://apple.com" title="Apple Website">Apple</a>.
</p>

<p>
  Here is an image: <img src="https://example.com/logo.png" alt="Logo" title="Our Logo">
</p>

<p>
  This link <a href="https://swift.org">appears twice</a> and uses the same number.
</p>

<p>
  For more, see <a href="https://developer.apple.com/documentation/swift">Swift Docs</a>.
</p>
"""

// MARK: - Reference style (default)
print("// Reference-style links (default):")
print("// ===================================")
let referenceMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    ReferenceLinkPlugin()          // default: reference style
])
print(referenceMarkdown)
print()

// MARK: - Inline style (opt-out)
print("// Inline links (classic):")
print("// ========================")
let inlineMarkdown = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    ReferenceLinkPlugin(inlineLinks: true)   // revert to inline
    // OR simply omit ReferenceLinkPlugin entirely
])
print(inlineMarkdown)
```

**Step 3: Capture actual output and write output files**

Write a temporary test:
```swift
func testPrintExample15() throws {
    let html = """ ... (same HTML as above) ... """
    let ref = try HTMLToMarkdown.convert(html, plugins: [BasePlugin(), CommonmarkPlugin(), ReferenceLinkPlugin()])
    let inline = try HTMLToMarkdown.convert(html, plugins: [BasePlugin(), CommonmarkPlugin()])
    print("=== REFERENCE ===\n\(ref)\n=== INLINE ===\n\(inline)\n=== END ===")
}
```
Run it, capture output, write to `output-reference.md` and `output-inline.md`.

**Step 4: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Examples/15-reference-links/ && git commit -m "examples: add Example 15 showing reference vs inline link styles

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 4: EmojiPlugin — Lookup Table

**Files:**
- Create: `Sources/plugin/emoji/emoji_table.swift`

**Note:** This is the largest single file in the task. The full GitHub emoji table has ~1800 entries. Include them all as a Swift dictionary literal.

**Step 1: Generate the emoji table**

The GitHub emoji API endpoint `https://api.github.com/emojis` returns a JSON object mapping shortcode → image URL. What we need is shortcode → Unicode character.

Use the Unicode Emoji test data. A widely used source is the `gemoji` gem's data: https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json

Each entry has `"aliases": ["smile"]` and `"emoji": "😄"`.

For the plan, provide a representative subset (first 50 entries). The implementer should download the full table from gemoji or use the curated list below and expand it.

**Download approach** (run once to build the table):
```bash
curl -s https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
print('// Auto-generated from github/gemoji')
print('let emojiShortcodes: [String: String] = [')
for item in data:
    emoji = item.get('emoji', '')
    if not emoji: continue
    for alias in item.get('aliases', []):
        print(f'    \"{alias}\": \"{emoji}\",')
print(']')
" > /tmp/emoji_table.swift
```

**Step 2: Create `Sources/plugin/emoji/emoji_table.swift`**

Start with a minimal working table (expand later):
```swift
// Emoji shortcode → Unicode character mapping (subset of GitHub's emoji list)
// Source: https://github.com/github/gemoji
let emojiShortcodes: [String: String] = [
    "smile": "😄",
    "smiley": "😃",
    "grinning": "😀",
    "laughing": "😆",
    "blush": "😊",
    "innocent": "😇",
    "wink": "😉",
    "heart_eyes": "😍",
    "kissing_heart": "😘",
    "kissing": "😗",
    "kissing_smiling_eyes": "😙",
    "kissing_closed_eyes": "😚",
    "yum": "😋",
    "stuck_out_tongue": "😛",
    "stuck_out_tongue_winking_eye": "😜",
    "stuck_out_tongue_closed_eyes": "😝",
    "money_mouth_face": "🤑",
    "hugs": "🤗",
    "thinking": "🤔",
    "zipper_mouth_face": "🤐",
    "raised_eyebrow": "🤨",
    "neutral_face": "😐",
    "expressionless": "😑",
    "no_mouth": "😶",
    "smirk": "😏",
    "unamused": "😒",
    "roll_eyes": "🙄",
    "grimacing": "😬",
    "lying_face": "🤥",
    "relieved": "😌",
    "pensive": "😔",
    "sleepy": "😪",
    "drooling_face": "🤤",
    "sleeping": "😴",
    "mask": "😷",
    "face_with_thermometer": "🤒",
    "face_with_head_bandage": "🤕",
    "nauseated_face": "🤢",
    "sneezing_face": "🤧",
    "hot_face": "🥵",
    "cold_face": "🥶",
    "woozy_face": "🥴",
    "dizzy_face": "😵",
    "exploding_head": "🤯",
    "cowboy_hat_face": "🤠",
    "partying_face": "🥳",
    "sunglasses": "😎",
    "nerd_face": "🤓",
    "monocle_face": "🧐",
    "confused": "😕",
    "worried": "😟",
    "slightly_frowning_face": "🙁",
    "frowning_face": "☹️",
    "open_mouth": "😮",
    "hushed": "😯",
    "astonished": "😲",
    "flushed": "😳",
    "pleading_face": "🥺",
    "anguished": "😧",
    "fearful": "😨",
    "cold_sweat": "😰",
    "disappointed_relieved": "😥",
    "cry": "😢",
    "sob": "😭",
    "scream": "😱",
    "confounded": "😖",
    "persevere": "😣",
    "disappointed": "😞",
    "sweat": "😓",
    "weary": "😩",
    "tired_face": "😫",
    "yawning_face": "🥱",
    "triumph": "😤",
    "rage": "😡",
    "angry": "😠",
    "skull": "💀",
    "skull_and_crossbones": "☠️",
    "poop": "💩",
    "clown_face": "🤡",
    "japanese_ogre": "👹",
    "japanese_goblin": "👺",
    "ghost": "👻",
    "alien": "👽",
    "space_invader": "👾",
    "robot": "🤖",
    "wave": "👋",
    "raised_back_of_hand": "🤚",
    "hand": "✋",
    "raised_hand_with_fingers_splayed": "🖐️",
    "vulcan_salute": "🖖",
    "ok_hand": "👌",
    "pinched_fingers": "🤌",
    "pinching_hand": "🤏",
    "v": "✌️",
    "crossed_fingers": "🤞",
    "love_you_gesture": "🤟",
    "metal": "🤘",
    "call_me_hand": "🤙",
    "point_left": "👈",
    "point_right": "👉",
    "point_up_2": "👆",
    "middle_finger": "🖕",
    "point_down": "👇",
    "point_up": "☝️",
    "thumbsup": "+1",
    "thumbsdown": "-1",
    "clap": "👏",
    "raised_hands": "🙌",
    "open_hands": "👐",
    "pray": "🙏",
    "handshake": "🤝",
    "nail_care": "💅",
    "ear": "👂",
    "nose": "👃",
    "eyes": "👀",
    "eye": "👁️",
    "tongue": "👅",
    "lips": "👄",
    "brain": "🧠",
    "heart": "❤️",
    "orange_heart": "🧡",
    "yellow_heart": "💛",
    "green_heart": "💚",
    "blue_heart": "💙",
    "purple_heart": "💜",
    "black_heart": "🖤",
    "broken_heart": "💔",
    "heavy_heart_exclamation": "❣️",
    "two_hearts": "💕",
    "revolving_hearts": "💞",
    "heartbeat": "💓",
    "heartpulse": "💗",
    "sparkling_heart": "💖",
    "cupid": "💘",
    "gift_heart": "💝",
    "heart_decoration": "💟",
    "peace_symbol": "☮️",
    "cross": "✝️",
    "star_and_crescent": "☪️",
    "star_of_david": "✡️",
    "yin_yang": "☯️",
    "wheel_of_dharma": "☸️",
    "fire": "🔥",
    "droplet": "💧",
    "wave_surf": "🌊",
    "tada": "🎉",
    "sparkles": "✨",
    "star": "⭐",
    "star2": "🌟",
    "dizzy": "💫",
    "boom": "💥",
    "anger": "💢",
    "question": "❓",
    "exclamation": "❗",
    "heavy_plus_sign": "➕",
    "heavy_minus_sign": "➖",
    "heavy_division_sign": "➗",
    "recycle": "♻️",
    "check": "✔️",
    "x": "❌",
    "o": "⭕",
    "stop_sign": "🛑",
    "no_entry": "⛔",
    "warning": "⚠️",
    "white_check_mark": "✅",
    "ballot_box_with_check": "☑️",
    "radio_button": "🔘",
    "link": "🔗",
    "paperclip": "📎",
    "memo": "📝",
    "pencil": "✏️",
    "pencil2": "✏️",
    "mag": "🔍",
    "mag_right": "🔎",
    "lock": "🔒",
    "unlock": "🔓",
    "key": "🔑",
    "hammer": "🔨",
    "wrench": "🔧",
    "gear": "⚙️",
    "computer": "💻",
    "desktop_computer": "🖥️",
    "keyboard": "⌨️",
    "phone": "📱",
    "iphone": "📱",
    "email": "📧",
    "mailbox": "📫",
    "inbox_tray": "📥",
    "outbox_tray": "📤",
    "package": "📦",
    "calendar": "📅",
    "date": "📅",
    "chart_with_upwards_trend": "📈",
    "chart_with_downwards_trend": "📉",
    "bar_chart": "📊",
    "clipboard": "📋",
    "pushpin": "📌",
    "round_pushpin": "📍",
    "bulb": "💡",
    "moneybag": "💰",
    "dollar": "💵",
    "yen": "💴",
    "euro": "💶",
    "pound": "💷",
    "credit_card": "💳",
    "gem": "💎",
    "trophy": "🏆",
    "medal_sports": "🏅",
    "1st_place_medal": "🥇",
    "2nd_place_medal": "🥈",
    "3rd_place_medal": "🥉",
    "soccer": "⚽",
    "basketball": "🏀",
    "football": "🏈",
    "baseball": "⚾",
    "tennis": "🎾",
    "volleyball": "🏐",
    "golf": "⛳",
    "ski": "🎿",
    "dart": "🎯",
    "video_game": "🎮",
    "joystick": "🕹️",
    "musical_note": "🎵",
    "notes": "🎶",
    "microphone": "🎤",
    "headphones": "🎧",
    "radio": "📻",
    "tv": "📺",
    "camera": "📷",
    "movie_camera": "🎥",
    "art": "🎨",
    "books": "📚",
    "book": "📖",
    "page_facing_up": "📄",
    "newspaper": "📰",
    "scroll": "📜",
    "pencil": "✏️",
    "rocket": "🚀",
    "satellite": "🛰️",
    "earth_americas": "🌎",
    "earth_africa": "🌍",
    "earth_asia": "🌏",
    "globe_with_meridians": "🌐",
    "world_map": "🗺️",
    "japan": "🗾",
    "sunny": "☀️",
    "partly_sunny": "⛅",
    "cloud": "☁️",
    "rainbow": "🌈",
    "snowflake": "❄️",
    "umbrella": "☂️",
    "zap": "⚡",
    "cyclone": "🌀",
    "fog": "🌫️",
    "wind_face": "🌬️",
    "cat": "🐱",
    "dog": "🐶",
    "mouse": "🐭",
    "hamster": "🐹",
    "rabbit": "🐰",
    "fox_face": "🦊",
    "bear": "🐻",
    "panda_face": "🐼",
    "koala": "🐨",
    "tiger": "🐯",
    "lion": "🦁",
    "cow": "🐮",
    "pig": "🐷",
    "frog": "🐸",
    "monkey_face": "🐵",
    "bird": "🐦",
    "penguin": "🐧",
    "chicken": "🐔",
    "hatching_chick": "🐣",
    "baby_chick": "🐤",
    "hatched_chick": "🐥",
    "duck": "🦆",
    "eagle": "🦅",
    "owl": "🦉",
    "bat": "🦇",
    "wolf": "🐺",
    "boar": "🐗",
    "horse": "🐴",
    "unicorn": "🦄",
    "bee": "🐝",
    "bug": "🐛",
    "butterfly": "🦋",
    "snail": "🐌",
    "shell": "🐚",
    "beetle": "🪲",
    "ant": "🐜",
    "mosquito": "🦟",
    "cricket": "🦗",
    "spider": "🕷️",
    "turtle": "🐢",
    "snake": "🐍",
    "lizard": "🦎",
    "dragon_face": "🐲",
    "dragon": "🐉",
    "sauropod": "🦕",
    "t-rex": "🦖",
    "whale": "🐳",
    "whale2": "🐋",
    "dolphin": "🐬",
    "fish": "🐟",
    "tropical_fish": "🐠",
    "blowfish": "🐡",
    "shark": "🦈",
    "octopus": "🐙",
    "crab": "🦀",
    "lobster": "🦞",
    "shrimp": "🦐",
    "squid": "🦑",
    "snail": "🐌",
    "rose": "🌹",
    "tulip": "🌷",
    "sunflower": "🌻",
    "hibiscus": "🌺",
    "cherry_blossom": "🌸",
    "blossom": "🌼",
    "bouquet": "💐",
    "mushroom": "🍄",
    "seedling": "🌱",
    "evergreen_tree": "🌲",
    "deciduous_tree": "🌳",
    "palm_tree": "🌴",
    "cactus": "🌵",
    "sheaf_of_rice": "🌾",
    "herb": "🌿",
    "shamrock": "☘️",
    "four_leaf_clover": "🍀",
    "maple_leaf": "🍁",
    "fallen_leaf": "🍂",
    "leaves": "🍃",
    "grapes": "🍇",
    "melon": "🍈",
    "watermelon": "🍉",
    "tangerine": "🍊",
    "lemon": "🍋",
    "banana": "🍌",
    "pineapple": "🍍",
    "mango": "🥭",
    "apple": "🍎",
    "green_apple": "🍏",
    "pear": "🍐",
    "peach": "🍑",
    "cherries": "🍒",
    "strawberry": "🍓",
    "blueberries": "🫐",
    "kiwi_fruit": "🥝",
    "tomato": "🍅",
    "coconut": "🥥",
    "avocado": "🥑",
    "eggplant": "🍆",
    "potato": "🥔",
    "carrot": "🥕",
    "corn": "🌽",
    "hot_pepper": "🌶️",
    "bell_pepper": "🫑",
    "cucumber": "🥒",
    "leafy_green": "🥬",
    "broccoli": "🥦",
    "garlic": "🧄",
    "onion": "🧅",
    "mushroom": "🍄",
    "peanuts": "🥜",
    "chestnut": "🌰",
    "bread": "🍞",
    "croissant": "🥐",
    "baguette_bread": "🥖",
    "flatbread": "🫓",
    "pretzel": "🥨",
    "bagel": "🥯",
    "pancakes": "🥞",
    "waffle": "🧇",
    "cheese": "🧀",
    "meat_on_bone": "🍖",
    "poultry_leg": "🍗",
    "cut_of_meat": "🥩",
    "bacon": "🥓",
    "hamburger": "🍔",
    "fries": "🍟",
    "pizza": "🍕",
    "hotdog": "🌭",
    "sandwich": "🥪",
    "taco": "🌮",
    "burrito": "🌯",
    "sushi": "🍣",
    "ramen": "🍜",
    "spaghetti": "🍝",
    "rice": "🍚",
    "rice_ball": "🍙",
    "bento": "🍱",
    "dumpling": "🥟",
    "fried_shrimp": "🍤",
    "egg": "🥚",
    "fried_egg": "🍳",
    "shallow_pan_of_food": "🥘",
    "stew": "🍲",
    "salad": "🥗",
    "popcorn": "🍿",
    "butter": "🧈",
    "salt": "🧂",
    "canned_food": "🥫",
    "bento": "🍱",
    "ice_cream": "🍨",
    "icecream": "🍦",
    "shaved_ice": "🍧",
    "cake": "🎂",
    "birthday": "🎂",
    "shortcake": "🍰",
    "cupcake": "🧁",
    "pie": "🥧",
    "chocolate_bar": "🍫",
    "candy": "🍬",
    "lollipop": "🍭",
    "honey_pot": "🍯",
    "coffee": "☕",
    "teapot": "🫖",
    "tea": "🍵",
    "sake": "🍶",
    "champagne": "🍾",
    "wine_glass": "🍷",
    "cocktail": "🍸",
    "tropical_drink": "🍹",
    "beer": "🍺",
    "beers": "🍻",
    "clinking_glasses": "🥂",
    "tumbler_glass": "🥃",
    "cup_with_straw": "🥤",
    "beverage_box": "🧃",
    "mate": "🧉",
    "ice_cube": "🧊",
    "house": "🏠",
    "office": "🏢",
    "hospital": "🏥",
    "bank": "🏦",
    "hotel": "🏨",
    "convenience_store": "🏪",
    "school": "🏫",
    "church": "⛪",
    "stadium": "🏟️",
    "night_with_stars": "🌃",
    "cityscape": "🏙️",
    "sunrise_over_mountains": "🌄",
    "sunrise": "🌅",
    "city_sunrise": "🌇",
    "city_sunset": "🌆",
    "bridge_at_night": "🌉",
    "milky_way": "🌌",
    "stars": "🌠",
    "sparkler": "🎇",
    "fireworks": "🎆",
    "car": "🚗",
    "taxi": "🚕",
    "bus": "🚌",
    "trolleybus": "🚎",
    "racing_car": "🏎️",
    "police_car": "🚓",
    "ambulance": "🚑",
    "fire_engine": "🚒",
    "minibus": "🚐",
    "truck": "🚚",
    "articulated_lorry": "🚛",
    "tractor": "🚜",
    "kick_scooter": "🛴",
    "bike": "🚲",
    "motor_scooter": "🛵",
    "motorcycle": "🏍️",
    "train": "🚆",
    "train2": "🚋",
    "subway": "🚇",
    "airplane": "✈️",
    "helicopter": "🚁",
    "ship": "🚢",
    "ferry": "⛴️",
    "boat": "⛵",
    "anchor": "⚓",
    "fuelpump": "⛽",
    "construction": "🚧",
    "vertical_traffic_light": "🚦",
    "traffic_light": "🚥",
    "rotating_light": "🚨",
    "moyai": "🗿",
    "statue_of_liberty": "🗽",
    "japan_castle": "🏯",
    "european_castle": "🏰",
    "mount_fuji": "🗻",
    "camping": "🏕️",
    "beach_umbrella": "🏖️",
    "desert": "🏜️",
    "desert_island": "🏝️",
    "national_park": "🏞️",
    "stadium": "🏟️",
    "tent": "⛺",
    "european_post_office": "🏤",
    "love_hotel": "🏩",
    "wedding": "💒",
    "department_store": "🏬",
    "factory": "🏭",
    "mega": "📣",
    "loudspeaker": "📢",
    "bell": "🔔",
    "no_bell": "🔕",
    "mute": "🔇",
    "sound": "🔉",
    "loud_sound": "🔊",
    "speaker": "🔈",
    "zzz": "💤",
    "speech_balloon": "💬",
    "thought_balloon": "💭",
    "anger_right": "🗯️",
    "clock1": "🕐",
    "clock2": "🕑",
    "clock3": "🕒",
    "clock4": "🕓",
    "clock5": "🕔",
    "clock6": "🕕",
    "clock7": "🕖",
    "clock8": "🕗",
    "clock9": "🕘",
    "clock10": "🕙",
    "clock11": "🕚",
    "clock12": "🕛",
    "hourglass": "⌛",
    "hourglass_flowing_sand": "⏳",
    "timer_clock": "⏱️",
    "stopwatch": "⏱️",
    "alarm_clock": "⏰",
    "mantelpiece_clock": "🕰️",
    "ballot_box_with_ballot": "🗳️",
    "pencil_alt": "📝",
    "file_folder": "📁",
    "open_file_folder": "📂",
    "card_index_dividers": "🗂️",
    "wastebasket": "🗑️",
    "file_cabinet": "🗄️",
    "spiral_notepad": "🗒️",
    "spiral_calendar": "🗓️",
    "card_index": "📇",
    "chart": "💹",
    "frame_with_picture": "🖼️",
    "compression": "🗜️",
    "label": "🏷️",
    "money_with_wings": "💸",
    "dollar": "💵",
    "100": "💯",
    "hash": "#️⃣",
    "asterisk": "*️⃣",
    "zero": "0️⃣",
    "one": "1️⃣",
    "two": "2️⃣",
    "three": "3️⃣",
    "four": "4️⃣",
    "five": "5️⃣",
    "six": "6️⃣",
    "seven": "7️⃣",
    "eight": "8️⃣",
    "nine": "9️⃣",
    "keycap_ten": "🔟",
    "arrow_forward": "▶️",
    "pause_button": "⏸️",
    "next_track_button": "⏭️",
    "stop_button": "⏹️",
    "rewind": "⏪",
    "arrow_backward": "◀️",
    "fast_forward": "⏩",
    "twisted_rightwards_arrows": "🔀",
    "repeat": "🔁",
    "repeat_one": "🔂",
    "arrow_up_small": "🔼",
    "arrow_down_small": "🔽",
    "arrow_double_up": "⏫",
    "arrow_double_down": "⏬",
    "arrow_right": "➡️",
    "arrow_left": "⬅️",
    "arrow_up": "⬆️",
    "arrow_down": "⬇️",
    "arrow_upper_right": "↗️",
    "arrow_lower_right": "↘️",
    "arrow_lower_left": "↙️",
    "arrow_upper_left": "↖️",
    "arrow_up_down": "↕️",
    "left_right_arrow": "↔️",
    "arrows_clockwise": "🔃",
    "arrows_counterclockwise": "🔄",
    "back": "🔙",
    "end": "🔚",
    "on": "🔛",
    "soon": "🔜",
    "top": "🔝",
    "place_of_worship": "🛐",
    "atom_symbol": "⚛️",
    "om": "🕉️",
    "fleur_de_lis": "⚜️",
    "beginner": "🔰",
    "trident": "🔱",
    "symbols": "🔣",
    "information_source": "ℹ️",
    "abc": "🔤",
    "abcd": "🔡",
    "capital_abcd": "🔠",
    "ng": "🆖",
    "ok": "🆗",
    "up": "🆙",
    "cool": "🆒",
    "new": "🆕",
    "free": "🆓",
    "sos": "🆘",
    "id": "🆔",
    "parking": "🅿️",
    "atm": "🏧",
    "sa": "🈂️",
    "passport_control": "🛂",
    "customs": "🛃",
    "baggage_claim": "🛄",
    "left_luggage": "🛅",
    "put_litter_in_its_place": "🚮",
    "potable_water": "🚰",
    "wheelchair": "♿",
    "mens": "🚹",
    "womens": "🚺",
    "restroom": "🚻",
    "baby_symbol": "🚼",
    "wc": "🚾",
    "no_smoking": "🚭",
    "u7981": "🈲",
    "accept": "🉑",
    "cl": "🆑",
    "vs": "🆚",
    "koko": "🈁",
    "eight_pointed_black_star": "✴️",
    "sos": "🆘",
    "white_flower": "💮",
    "hundred_points": "💯",
    "name_badge": "📛",
    "no_entry_sign": "🚫",
    "x": "❌",
    "o": "⭕",
    "wavy_dash": "〰️",
    "part_alternation_mark": "〽️",
    "congratulations": "㊗️",
    "secret": "㊙️",
    "m": "Ⓜ️",
    "red_circle": "🔴",
    "orange_circle": "🟠",
    "yellow_circle": "🟡",
    "green_circle": "🟢",
    "blue_circle": "🔵",
    "purple_circle": "🟣",
    "brown_circle": "🟤",
    "black_circle": "⚫",
    "white_circle": "⚪",
    "red_square": "🟥",
    "orange_square": "🟧",
    "yellow_square": "🟨",
    "green_square": "🟩",
    "blue_square": "🟦",
    "purple_square": "🟪",
    "brown_square": "🟫",
    "black_large_square": "⬛",
    "white_large_square": "⬜",
    "black_medium_square": "◼️",
    "white_medium_square": "◻️",
    "black_medium_small_square": "◾",
    "white_medium_small_square": "◽",
    "black_small_square": "▪️",
    "white_small_square": "▫️",
    "large_blue_diamond": "🔷",
    "large_orange_diamond": "🔶",
    "small_blue_diamond": "🔹",
    "small_orange_diamond": "🔸",
    "small_red_triangle": "🔺",
    "small_red_triangle_down": "🔻",
    "radio_button": "🔘",
    "white_square_button": "🔳",
    "black_square_button": "🔲",
    "checkered_flag": "🏁",
    "triangular_flag_on_post": "🚩",
    "crossed_flags": "🎌",
    "black_flag": "🏴",
    "white_flag": "🏳️",
    "rainbow_flag": "🏳️‍🌈",
    "transgender_flag": "🏳️‍⚧️",
    "pirate_flag": "🏴‍☠️",
    "us": "🇺🇸",
    "gb": "🇬🇧",
    "uk": "🇬🇧",
    "cn": "🇨🇳",
    "jp": "🇯🇵",
    "fr": "🇫🇷",
    "de": "🇩🇪",
    "it": "🇮🇹",
    "es": "🇪🇸",
    "ru": "🇷🇺",
    "ca": "🇨🇦",
    "au": "🇦🇺",
    "br": "🇧🇷",
    "in": "🇮🇳",
    "kr": "🇰🇷",
    "mx": "🇲🇽",
    "ng": "🇳🇬",
    "za": "🇿🇦",
    "tr": "🇹🇷",
    "sg": "🇸🇬",
    "se": "🇸🇪",
    "no": "🇳🇴",
    "fi": "🇫🇮",
    "dk": "🇩🇰",
    "nl": "🇳🇱",
    "be": "🇧🇪",
    "ch": "🇨🇭",
    "at": "🇦🇹",
    "pl": "🇵🇱",
    "pt": "🇵🇹",
    "gr": "🇬🇷",
    "nz": "🇳🇿",
    "ar": "🇦🇷",
    "cl": "🇨🇱",
    "co": "🇨🇴",
    "eg": "🇪🇬",
    "id": "🇮🇩",
    "il": "🇮🇱",
    "pk": "🇵🇰",
    "ph": "🇵🇭",
    "th": "🇹🇭",
    "tw": "🇹🇼",
    "vn": "🇻🇳",
    "my": "🇲🇾",
    "eu": "🇪🇺",
    "un": "🇺🇳",
]
```

**Note:** The table above is a starting subset. The full GitHub emoji table has ~1800 entries. The implementer SHOULD download and use the full gemoji database:
```bash
curl -s https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json | python3 -c "
import json, sys
data = json.load(sys.stdin)
entries = {}
for item in data:
    emoji_char = item.get('emoji', '')
    if not emoji_char: continue
    for alias in item.get('aliases', []):
        if alias not in entries:
            entries[alias] = emoji_char
print('let emojiShortcodes: [String: String] = [')
for k, v in sorted(entries.items()):
    # Escape backslash-u sequences
    print(f'    \"{k}\": \"{v}\",')
print(']')
" > Sources/plugin/emoji/emoji_table.swift
```
If network access is unavailable, use the subset above as the starting point.

**Step 2: Run build to verify the table compiles**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift build 2>&1 | tail -5
```

**Step 3: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Sources/plugin/emoji/emoji_table.swift && git commit -m "feat: add bundled emoji shortcode lookup table

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 5: EmojiPlugin — Core Implementation

**Files:**
- Create: `Sources/plugin/emoji/emoji.swift`
- Create: `Tests/plugin-emoji_test.swift`

**Step 1: Write failing tests first**

`Tests/plugin-emoji_test.swift`:
```swift
import XCTest
@testable import HTMLToMarkdown

private func convert(_ html: String, style: EmojiOutputStyle = .shortcode) throws -> String {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(EmojiPlugin(outputStyle: style))
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class EmojiPluginTests: XCTestCase {

    func testGitHubEmojiImageToShortcode() throws {
        let html = "<p>I am <img class=\"emoji\" alt=\":smile:\" src=\"https://github.githubassets.com/images/icons/emoji/unicode/1f604.png\"> today.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains(":smile:"), "Expected :smile: shortcode in: \(result)")
        XCTAssertFalse(result.contains("<img"), "Should not have img tag in output: \(result)")
    }

    func testGitHubEmojiImageToUnicode() throws {
        let html = "<p>I am <img class=\"emoji\" alt=\":smile:\" src=\"https://github.githubassets.com/images/icons/emoji/unicode/1f604.png\"> today.</p>"
        let result = try convert(html, style: .unicode)
        XCTAssertTrue(result.contains("😄"), "Expected unicode emoji in: \(result)")
        XCTAssertFalse(result.contains(":smile:"), "Should not have shortcode in unicode mode: \(result)")
    }

    func testUnicodeEmojiInTextToShortcode() throws {
        let html = "<p>Party time 🎉 yay!</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains(":tada:"), "Expected :tada: shortcode in: \(result)")
        XCTAssertFalse(result.contains("🎉"), "Should not have raw emoji in shortcode mode: \(result)")
    }

    func testUnicodeEmojiInTextUnicodeMode() throws {
        let html = "<p>Party time 🎉 yay!</p>"
        let result = try convert(html, style: .unicode)
        XCTAssertTrue(result.contains("🎉"), "Unicode emoji should stay in unicode mode: \(result)")
    }

    func testUnknownEmojiImageAltPassthrough() throws {
        // If alt is not ":shortcode:" format, use alt text as-is
        let html = "<p><img class=\"emoji\" alt=\"clapping\" src=\"...\"></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("clapping"), "Alt text should pass through: \(result)")
    }

    func testNonEmojiImageUnaffected() throws {
        let html = "<p><img src=\"https://example.com/photo.jpg\" alt=\"A photo\"></p>"
        let result = try convert(html)
        XCTAssertFalse(result.contains(":"), "Non-emoji img should not produce shortcode: \(result)")
    }

    func testCodeBlockEmojiUntouched() throws {
        let html = "<pre><code>emoji: 🎉 not converted</code></pre>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("🎉"), "Raw emoji in code block must stay as-is: \(result)")
        XCTAssertFalse(result.contains(":tada:"), "Should not convert emoji in code block: \(result)")
    }

    func testFireEmojiToShortcode() throws {
        let html = "<p>🔥 Hot stuff!</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains(":fire:"), "Expected :fire: shortcode in: \(result)")
    }
}
```

**Step 2: Run to confirm compile failure**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test --filter EmojiPluginTests 2>&1 | tail -5
```

**Step 3: Implement EmojiPlugin**

`Sources/plugin/emoji/emoji.swift`:
```swift
import Foundation
import SwiftSoup

public enum EmojiOutputStyle {
    case shortcode   // :smile: — GFM compatible
    case unicode     // 😄 — raw Unicode
}

public class EmojiPlugin: Plugin {
    public var name: String { return "emoji" }
    let outputStyle: EmojiOutputStyle

    // Reverse lookup: Unicode → shortcode (built once at init)
    private let unicodeToShortcode: [String: String]

    public init(outputStyle: EmojiOutputStyle = .shortcode) {
        self.outputStyle = outputStyle
        // Build reverse map: emoji_char → first shortcode that maps to it
        var reverse: [String: String] = [:]
        for (shortcode, char) in emojiShortcodes {
            if reverse[char] == nil {
                reverse[char] = shortcode
            }
        }
        self.unicodeToShortcode = reverse
    }

    public func initialize(conv: Converter) throws {
        registerEmojiImageRenderer(conv: conv)
        if outputStyle == .shortcode {
            registerEmojiTextTransformer(conv: conv)
        }
    }

    func registerEmojiImageRenderer(conv: Converter) {
        let style = self.outputStyle
        conv.Register.rendererFor("img", .inline, { [weak self] ctx, w, n in
            guard let element = n as? Element else { return .tryNext }
            guard element.hasClass("emoji") else { return .tryNext }
            guard let self = self else { return .tryNext }

            let alt = (try? element.attr("alt")) ?? ""

            // alt is typically ":shortcode:" for GitHub emoji images
            if alt.hasPrefix(":") && alt.hasSuffix(":") {
                let shortcode = String(alt.dropFirst().dropLast())
                switch style {
                case .shortcode:
                    w.writeString(":\(shortcode):")
                case .unicode:
                    let char = emojiShortcodes[shortcode] ?? alt
                    w.writeString(char)
                }
            } else {
                // Not in :shortcode: format — output alt text
                w.writeString(alt)
            }
            return .success
        }, priority: PriorityEarly)
    }

    func registerEmojiTextTransformer(conv: Converter) {
        let reverseMap = self.unicodeToShortcode
        conv.Register.textTransformer({ ctx, text in
            var result = text
            // Replace each Unicode emoji character with its shortcode
            // Process in reverse character order to preserve indices
            var chars = Array(text.unicodeScalars)
            var output = ""
            var i = 0
            while i < chars.count {
                let scalar = chars[i]
                // Check if this scalar starts an emoji sequence
                // Build a string with this scalar and check against our table
                let singleChar = String(scalar)
                if let shortcode = reverseMap[singleChar] {
                    output += ":\(shortcode):"
                } else {
                    output += singleChar
                }
                i += 1
            }
            return output
        }, priority: PriorityStandard)
    }
}
```

**Important note on text transformer:** The above approach converts each Unicode scalar individually. Some emoji are multi-scalar sequences (e.g., 👁️ = U+1F441 + U+FE0F variation selector, 🏳️‍🌈 = flag + ZWJ + etc.). The lookup table uses full grapheme clusters (Swift's `Character`). A better approach:

```swift
func registerEmojiTextTransformer(conv: Converter) {
    let reverseMap = self.unicodeToShortcode
    conv.Register.textTransformer({ ctx, text in
        var output = ""
        for char in text {
            let charStr = String(char)
            if let shortcode = reverseMap[charStr] {
                output += ":\(shortcode):"
            } else {
                output += charStr
            }
        }
        return output
    }, priority: PriorityStandard)
}
```

This iterates over Swift `Character` (grapheme clusters), which correctly handles multi-scalar emoji. Use this version.

**Step 4: Run tests**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test --filter EmojiPluginTests 2>&1 | tail -25
```

Debug notes:
- `testUnicodeEmojiInTextToShortcode`: The text transformer runs on `#text` nodes. Make sure `🎉` in `<p>Party time 🎉 yay!</p>` actually reaches the text transformer. It should — text nodes pass through `textTransformHandlers`. Check that `emojiShortcodes["tada"] == "🎉"` — yes it's in our table. The reverse map should have `"🎉": "tada"`.  
- `testCodeBlockEmojiUntouched`: `<pre><code>` uses `extractRawText()` which bypasses text transformers. ✓
- Test failures for unrecognized emoji: emoji not in our 200-entry table will pass through unchanged. That's acceptable behavior.

**Step 5: Run all tests**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test 2>&1 | tail -5
```

**Step 6: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Sources/plugin/emoji/emoji.swift Tests/plugin-emoji_test.swift && git commit -m "feat: add EmojiPlugin with shortcode and Unicode output modes

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 6: Emoji Golden Files + Example

**Files:**
- Create: `Tests/data/plugin/emoji/testdata/GoldenFiles/emoji.in.html`
- Create: `Tests/data/plugin/emoji/testdata/GoldenFiles/emoji.out.md`
- Modify: `Tests/swift-golden_test.swift` — add emoji golden test
- Create: `Examples/16-emoji/code.swift`
- Create: `Examples/16-emoji/output.md`

**Step 1: Create emoji golden file input**

`Tests/data/plugin/emoji/testdata/GoldenFiles/emoji.in.html`:
```html
<p>GitHub emoji image: <img class="emoji" alt=":smile:" src="https://github.githubassets.com/images/icons/emoji/unicode/1f604.png"></p>

<p>Unicode emoji in text: Party time 🎉 and fire 🔥!</p>

<p>Unknown emoji image: <img class="emoji" alt="custom-emoji" src="..."></p>

<pre><code>Emoji in code: 🎉 not converted</code></pre>
```

**Step 2: Capture actual output and write golden file**

Use a temporary print test:
```swift
func testPrintEmojiGolden() throws {
    let html = """ ... (above HTML) ... """
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(EmojiPlugin())
    let result = try conv.convertString(html)
    print("=== EMOJI OUTPUT ===\n\(result)\n=== END ===")
}
```
Run: `swift test --filter testPrintEmojiGolden`

**Step 3: Add emoji golden test to swift-golden_test.swift**

```swift
func testEmojiGolden() {
    let base = "\(goldenBase)/plugin/emoji/testdata/GoldenFiles/emoji"
    runGoldenFile(inputPath: "\(base).in.html", expectedPath: "\(base).out.md",
                  plugins: [BasePlugin(), CommonmarkPlugin(), EmojiPlugin()],
                  description: "emoji/emoji")
}
```

Make sure the `Tests/data/plugin/emoji/testdata/GoldenFiles/` directory exists (create it).

**Step 4: Create Example 16**

`Examples/16-emoji/code.swift`:
```swift
import HTMLToMarkdown

// GitHub renders emoji as <img class="emoji"> tags.
// The EmojiPlugin converts these back to :shortcode: syntax
// (or to raw Unicode characters in .unicode mode).

let html = """
<h1>Emoji Examples</h1>

<h2>GitHub Emoji Images</h2>
<p>
  GitHub renders emoji as images:
  <img class="emoji" alt=":smile:" src="https://github.githubassets.com/images/icons/emoji/unicode/1f604.png">
  <img class="emoji" alt=":tada:" src="https://github.githubassets.com/images/icons/emoji/unicode/1f389.png">
  <img class="emoji" alt=":fire:" src="https://github.githubassets.com/images/icons/emoji/unicode/1f525.png">
</p>

<h2>Unicode Emoji in HTML Text</h2>
<p>Unicode emoji: 😀 🎉 🔥 ❤️ ⭐ 🚀</p>

<h2>Code Block (Unaffected)</h2>
<pre><code>
# This emoji 🎉 stays as-is in code
emoji_text = "Party time! 🎉"
</code></pre>
"""

// Shortcode mode (default) — GFM compatible
print("// Shortcode mode (GFM-compatible):")
let shortcode = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    EmojiPlugin()  // default: .shortcode
])
print(shortcode)
print()

// Unicode mode — raw Unicode characters
print("// Unicode mode:")
let unicode = try HTMLToMarkdown.convert(html, plugins: [
    BasePlugin(),
    CommonmarkPlugin(),
    EmojiPlugin(outputStyle: .unicode)
])
print(unicode)
```

Capture output, write to `Examples/16-emoji/output.md`.

**Step 5: Run all tests**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test 2>&1 | tail -5
```

**Step 6: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add Tests/data/plugin/emoji/ Tests/swift-golden_test.swift Examples/16-emoji/ && git commit -m "test: add emoji golden files; examples: add emoji example

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

---

## Task 7: README Update

**Files:**
- Modify: `README.md`
- Modify: `Examples/README.md` (if it exists)

**Step 1: Add to plugin table in README.md**

Find the last plugin row (after `LinkifyPlugin`) and add:
```markdown
| `ReferenceLinkPlugin` | `plugin/referencelinks` | Converts inline links to numbered reference-style links (`[text][1]`) collected at document bottom; `inlineLinks: true` reverts to inline |
| `EmojiPlugin` | `plugin/emoji` | Converts GitHub `<img class="emoji">` tags and Unicode emoji in text to `:shortcode:` syntax (or raw Unicode); GFM-compatible |
```

**Step 2: Add to examples list**

```markdown
- [15 - Reference Links](Examples/15-reference-links/) — reference-style vs inline links side by side
- [16 - Emoji](Examples/16-emoji/) — GitHub emoji shortcodes and Unicode emoji
```

**Step 3: Run all tests**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && swift test 2>&1 | tail -5
```

Expected: 328 + new tests, 0 failures.

**Step 4: Commit**
```bash
cd /Users/wgu/Code/xcode/html-to-markdown && git add README.md && git commit -m "docs: add ReferenceLinkPlugin and EmojiPlugin to README

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```
