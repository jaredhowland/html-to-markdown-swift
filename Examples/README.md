# Examples

Each example has a `code.swift` file with the full conversion code, along with one or more `output*.md` files showing the generated Markdown.

| # | Example | Plugins used | What it shows |
|---|---------|-------------|---------------|
| 01 | [Basic Conversion](01-basic-conversion/) | `BasePlugin`, `CommonmarkPlugin` | Headings, bold/italic, links, code blocks, blockquotes, ordered/unordered lists |
| 02 | [Vita with Frontmatter](02-vita-with-frontmatter/) | `FrontmatterPlugin` | Extracts `<title>` and `<meta>` tags into YAML frontmatter; strips nav/header/footer with `.excludeSelectors` |
| 03 | [Wikipedia Article](03-wikipedia-article/) | `TablePlugin` | Converts a Wikipedia article: pipe tables, domain-relative links resolved with `.domain`, heavy use of `.excludeSelectors` to strip site chrome |
| 04 | [Exclude Navigation](04-exclude-navigation/) | `FrontmatterPlugin` | Blog post with nav, sidebar, and footer removed using CSS-selector exclusions |
| 05 | [Custom Plugin](05-custom-plugin/) | Custom `UppercaseHeadingsPlugin` | How to write a `Plugin` implementation that intercepts specific tags — renders all heading text in uppercase |
| 06 | [GFM Features](06-gfm-features/) | `GFMPlugin` | Task list checkboxes, `~~strikethrough~~`, pipe tables, and definition lists using `GFMPlugin` |
| 07 | [Atlassian Markdown](07-atlassian-markdown/) | `AtlassianPlugin` | Autolinks, width-and-height image sizing, strikethrough, and tables for Bitbucket/Jira flavored Markdown |
| 08 | [MultiMarkdown](08-multimarkdown/) | `MultiMarkdownPlugin` | Subscript `~x~`, superscript `^x^`, definition lists, `<figure>`/`<figcaption>`, and footnotes for MMD output |
| 09 | [YouTube & Vimeo Embeds](09-youtube-vimeo/) | `YouTubeEmbedPlugin`, `VimeoEmbedPlugin` | `<iframe>` embeds converted to a clickable thumbnail image (YouTube) or a plain link (Vimeo) |
| 10 | [Atlassian Confluence](10-atlassian-confluence/) | `AtlassianPlugin` | Confluence-specific XML macros: `<ac:structured-macro>` code blocks, `<ri:attachment>` file/image links, `<ac:image>` sizing |
| 11 | [Markdown Extra](11-markdown-extra/) | `MarkdownExtraPlugin` | Definition lists, `[^footnote]` references, `<abbr>` abbreviation expansion, and `{#header-id}` anchors |
| 12 | [Pandoc](12-pandoc/) | `PandocPlugin` | LaTeX math (`$...$` and `$$...$$`), definition lists, footnotes, subscript/superscript, and header ID attributes |
| 13 | [R Markdown](13-rmarkdown/) | `RMarkdownPlugin` | Extends Pandoc output: tabset `<div>` blocks flattened to `##` sections, `<figcaption>` captions, and display math |
| 14 | [Typography](14-typography/) | `TypographyPlugin` | Smart curly quotes (English and German styles), typographic replacements (`---`→`—`, `(c)`→`©`, etc.), and bare-URL linkification; code blocks are left untouched |
| 15 | [Reference Links](15-reference-links/) | `ReferenceLinkPlugin` | Links collected as a numbered reference list at the bottom of the document vs `inlineLinks: true` mode to keep them inline |
| 16 | [Emoji](16-emoji/) | `EmojiPlugin` | `<img class="emoji">` GitHub emoji images and Unicode emoji converted to `:shortcode:` (default) or kept as Unicode characters |

## Running an example

Each `code.swift` is a standalone Swift script. The quickest way to run one:

```bash
cd Examples/01-basic-conversion
swift code.swift
```

For examples that fetch a live URL, uncomment the `String(contentsOf:)` line and replace the inline `html` variable with the fetched result.

