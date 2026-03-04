# Reference Links & Emoji Plugin Design

## Approved Design

### ReferenceLinkPlugin

A standalone `ReferenceLinkPlugin` that post-processes link and image rendering to produce
reference-style Markdown rather than inline links.

**Behavior:**
- `<a href="URL" title="T">text</a>` → `[text][1]` inline, `[1]: URL "T"` collected at bottom
- `<img src="URL" alt="alt" title="T">` → `![alt][1]` inline, `[1]: URL "T"` collected at bottom
- Same URL → same reference number (deduplication)
- Numbers assigned in first-encounter order, global across document
- Reference block appended after footnotes (post-renderer priority 1055)
- Format: one blank line before block, one blank line after, then `[1]: url "title"` per line
- `ReferenceLinkPlugin(inlineLinks: true)` → disables itself (renders inline, same as default CommonmarkPlugin)

**Architecture:**
- Override `<a>` at `PriorityEarly` (100) — beats CommonmarkPlugin's `PriorityStandard` (500)
- Override `<img>` at `PriorityEarly` (100)
- Use `ctx.updateState` to collect `[RefLink]` array during rendering
- Post-renderer priority 1055 (after pandoc/ME footnotes at 1050, before abbreviations at 1060)

**Non-standard link types** (footnote refs, GFM task items) register their own renderers
at PriorityEarly and check for specific HTML attributes first — they are unaffected.

---

### EmojiPlugin

Converts HTML emoji representations to Markdown emoji shortcodes (`:smile:`) or Unicode.

**Job 1 — GitHub `<img class="emoji">` tags:**
`<img class="emoji" alt=":smile:" src="...">` → `:smile:` (shortcode) or `😄` (unicode)

**Job 2 — Unicode emoji in text:**
Text nodes containing literal Unicode emoji (😀) → `:smiley:` in shortcode mode, left as-is in unicode mode.

**Output style (init param):**
- `.shortcode` (default): GFM-compatible, renders in GitHub/GitLab/Obsidian etc.
- `.unicode`: raw Unicode characters

**Bundled table:** `Sources/plugin/emoji/emoji_table.swift` — Swift dictionary literal
`[String: String]` mapping shortcode → Unicode character (~1800 GitHub emoji).

**Note:** Code blocks (`<pre>`, `<code>`) are unaffected — text transformers skip those.
