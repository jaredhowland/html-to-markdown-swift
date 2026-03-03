import XCTest
@testable import HTMLToMarkdown

class HTMLToMarkdownTests: XCTestCase {

    private func convert(_ html: String, options: [ConverterOption] = []) throws -> String {
        return try HTMLToMarkdown.convert(html, options: options)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convert(_ html: String, plugins: [Plugin]) throws -> String {
        return try HTMLToMarkdown.convert(html, plugins: plugins)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func convertPlugins(_ html: String, options: CommonmarkOptions) throws -> String {
        return try HTMLToMarkdown.convert(html, plugins: [BasePlugin(), CommonmarkPlugin(options: options)])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Bold / Italic

    func testBold() throws {
        XCTAssertEqual(try convert("<strong>Bold</strong>"), "**Bold**")
    }

    func testBoldTag() throws {
        XCTAssertEqual(try convert("<b>Bold</b>"), "**Bold**")
    }

    func testItalic() throws {
        XCTAssertEqual(try convert("<em>Italic</em>"), "*Italic*")
    }

    func testItalicTag() throws {
        XCTAssertEqual(try convert("<i>Italic</i>"), "*Italic*")
    }

    func testCustomStrongDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.strongDelimiter = "__"
        XCTAssertEqual(try convertPlugins("<strong>Bold</strong>", options: opts), "__Bold__")
    }

    func testCustomEmDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.emDelimiter = "_"
        XCTAssertEqual(try convertPlugins("<em>Italic</em>", options: opts), "_Italic_")
    }

    // MARK: - Headings

    func testH1() throws {
        XCTAssertEqual(try convert("<h1>Heading 1</h1>"), "# Heading 1")
    }

    func testH2() throws {
        XCTAssertEqual(try convert("<h2>Heading 2</h2>"), "## Heading 2")
    }

    func testH3() throws {
        XCTAssertEqual(try convert("<h3>Heading 3</h3>"), "### Heading 3")
    }

    func testH4() throws {
        XCTAssertEqual(try convert("<h4>Heading 4</h4>"), "#### Heading 4")
    }

    func testH5() throws {
        XCTAssertEqual(try convert("<h5>Heading 5</h5>"), "##### Heading 5")
    }

    func testH6() throws {
        XCTAssertEqual(try convert("<h6>Heading 6</h6>"), "###### Heading 6")
    }

    func testH7PlainText() throws {
        // h7+ has no ATX equivalent; render as plain text
        XCTAssertEqual(try convert("<h7>Heading 7</h7>"), "Heading 7")
    }

    func testHeadingTrailingHash() throws {
        XCTAssertEqual(try convert("<h1>Heading #</h1>"), "# Heading \\#")
    }

    func testHeadingTrailingDoubleHash() throws {
        // Last # should be escaped; preceding ones do not need escaping
        XCTAssertEqual(try convert("<h1>Heading ##</h1>"), "# Heading #\\#")
    }

    func testHeadingHashOnly() throws {
        XCTAssertEqual(try convert("<h1>#</h1>"), "# \\#")
    }

    func testEmptyHeadingProducesNothing() throws {
        XCTAssertEqual(try convert("<h1></h1>"), "")
        XCTAssertEqual(try convert("<h1> </h1>"), "")
    }

    func testSetextH1() throws {
        var opts = CommonmarkOptions()
        opts.headingStyle = .setext
        let result = try convertPlugins("<h1>Hello</h1>", options: opts)
        XCTAssertEqual(result, "Hello\n=====")
    }

    func testSetextH2() throws {
        var opts = CommonmarkOptions()
        opts.headingStyle = .setext
        let result = try convertPlugins("<h2>Hello</h2>", options: opts)
        XCTAssertEqual(result, "Hello\n-----")
    }

    func testSetextH3FallsBackToATX() throws {
        var opts = CommonmarkOptions()
        opts.headingStyle = .setext
        let result = try convertPlugins("<h3>Hello</h3>", options: opts)
        XCTAssertEqual(result, "### Hello")
    }

    func testSetextH1WithBreak() throws {
        var opts = CommonmarkOptions()
        opts.headingStyle = .setext
        let result = try convertPlugins("<h1>important<br/>heading</h1>", options: opts)
        XCTAssertEqual(result, "important  \nheading\n===========")
    }

    func testATXH1WithBreakCollapsed() throws {
        let result = try convert("<h1>important<br/>heading</h1>")
        XCTAssertEqual(result, "# important heading")
    }

    // MARK: - Links

    func testLink() throws {
        XCTAssertEqual(try convert("<a href=\"https://example.com\">Link</a>"), "[Link](https://example.com)")
    }

    func testLinkWithTitle() throws {
        XCTAssertEqual(
            try convert("<a href=\"https://example.com\" title=\"Example\">Link</a>"),
            "[Link](https://example.com \"Example\")"
        )
    }

    func testRelativeLinkWithDomain() throws {
        let result = try convert("<a href=\"/page\">Link</a>", options: [.domain("https://example.com")])
        XCTAssertEqual(result, "[Link](https://example.com/page)")
    }

    func testLinkNoHrefAttribute() throws {
        // <a> with no href at all should render as [text]()
        XCTAssertEqual(try convert("<a>no href</a>"), "[no href]()")
    }

    func testEmptyHrefRender() throws {
        XCTAssertEqual(try convert("<a href=\"\">text</a>"), "[text]()")
    }

    func testEmptyHrefSkip() throws {
        var opts = CommonmarkOptions()
        opts.linkEmptyHrefBehavior = .skip
        XCTAssertEqual(try convertPlugins("<a href=\"\">text</a>", options: opts), "text")
    }

    func testEmptyContentSkip() throws {
        var opts = CommonmarkOptions()
        opts.linkEmptyContentBehavior = .skip
        XCTAssertEqual(try convertPlugins("<a href=\"https://example.com\"></a>", options: opts), "")
    }

    // MARK: - Images

    func testImage() throws {
        XCTAssertEqual(try convert("<img src=\"image.png\" alt=\"An image\">"), "![An image](image.png)")
    }

    func testImageWithTitle() throws {
        XCTAssertEqual(
            try convert("<img src=\"image.png\" alt=\"An image\" title=\"Image Title\">"),
            "![An image](image.png \"Image Title\")"
        )
    }

    func testImageEmptySrc() throws {
        XCTAssertEqual(try convert("<img src=\"\" alt=\"empty\">"), "")
    }

    // MARK: - Code

    func testInlineCode() throws {
        XCTAssertEqual(try convert("<code>let x = 5</code>"), "`let x = 5`")
    }

    func testCodeBlock() throws {
        let result = try convert("<pre><code>let x = 5</code></pre>")
        XCTAssertEqual(result, "```\nlet x = 5\n```")
    }

    func testCodeBlockWithLanguage() throws {
        let result = try convert("<pre><code class=\"language-swift\">let x = 5</code></pre>")
        XCTAssertEqual(result, "```swift\nlet x = 5\n```")
    }

    func testCodeBlockWithTildeFence() throws {
        var opts = CommonmarkOptions()
        opts.codeBlockFence = "~~~"
        let result = try convertPlugins("<pre><code>code here</code></pre>", options: opts)
        XCTAssertEqual(result, "~~~\ncode here\n~~~")
    }

    // MARK: - Blockquote

    func testBlockquote() throws {
        XCTAssertEqual(try convert("<blockquote>Quote text</blockquote>"), "> Quote text")
    }

    // MARK: - Lists

    func testUnorderedList() throws {
        let html = "<ul><li>A</li><li>B</li></ul>"
        let result = try convert(html)
        XCTAssertEqual(result, "- A\n- B")
    }

    func testOrderedList() throws {
        let html = "<ol><li>A</li><li>B</li></ol>"
        let result = try convert(html)
        XCTAssertEqual(result, "1. A\n2. B")
    }

    func testOrderedListWithStart() throws {
        let html = "<ol start=\"3\"><li>A</li><li>B</li></ol>"
        let result = try convert(html)
        XCTAssertEqual(result, "3. A\n4. B")
    }

    func testOrderedListPaddingCrossesDigitBoundary() throws {
        // start=9, 2 items → "09." and "10." (zero-padded to match digit count of last item)
        let html = "<ol start=\"9\"><li>a</li><li>b</li></ol>"
        let result = try convert(html)
        XCTAssertEqual(result, "09. a\n10. b")
    }

    func testOrderedListNoPaddingWithinSameDigitCount() throws {
        // start=8, 2 items → "8." and "9." (no padding needed, both single digit)
        let html = "<ol start=\"8\"><li>a</li><li>b</li></ol>"
        let result = try convert(html)
        XCTAssertEqual(result, "8. a\n9. b")
    }

    func testCustomBulletMarker() throws {
        var opts = CommonmarkOptions()
        opts.bulletListMarker = "*"
        let result = try convertPlugins("<ul><li>A</li><li>B</li></ul>", options: opts)
        XCTAssertEqual(result, "* A\n* B")
    }

    func testCustomBulletMarkerPlus() throws {
        var opts = CommonmarkOptions()
        opts.bulletListMarker = "+"
        let result = try convertPlugins("<ul><li>A</li><li>B</li></ul>", options: opts)
        XCTAssertEqual(result, "+ A\n+ B")
    }

    func testNestedList() throws {
        let html = "<ul><li>Item 1<ul><li>Nested 1</li></ul></li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("- Item 1"))
        XCTAssertTrue(result.contains("Nested 1"))
    }

    // MARK: - Horizontal Rule

    func testHorizontalRule() throws {
        XCTAssertEqual(try convert("<hr>"), "* * *")
    }

    func testCustomHorizontalRuleDash() throws {
        var opts = CommonmarkOptions()
        opts.horizontalRule = "---"
        XCTAssertEqual(try convertPlugins("<hr>", options: opts), "---")
    }

    func testCustomHorizontalRuleUnderscore() throws {
        var opts = CommonmarkOptions()
        opts.horizontalRule = "___"
        XCTAssertEqual(try convertPlugins("<hr>", options: opts), "___")
    }

    // MARK: - Line Break

    func testLineBreak() throws {
        let result = try convert("Line 1<br>Line 2")
        XCTAssertTrue(result.contains("Line 1"))
        XCTAssertTrue(result.contains("Line 2"))
    }

    // MARK: - Paragraph

    func testParagraph() throws {
        let result = try convert("<p>This is a paragraph.</p>")
        XCTAssertEqual(result, "This is a paragraph.")
    }

    func testMultipleParagraphs() throws {
        let result = try convert("<p>First.</p><p>Second.</p>")
        XCTAssertTrue(result.contains("First."))
        XCTAssertTrue(result.contains("Second."))
    }

    // MARK: - Validation Errors

    func testValidationErrorEmDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.emDelimiter = "x"
        XCTAssertThrowsError(try convertPlugins("<em>text</em>", options: opts))
    }

    func testValidationErrorStrongDelimiter() throws {
        var opts = CommonmarkOptions()
        opts.strongDelimiter = "xx"
        XCTAssertThrowsError(try convertPlugins("<strong>text</strong>", options: opts))
    }

    func testValidationErrorBulletMarker() throws {
        var opts = CommonmarkOptions()
        opts.bulletListMarker = "x"
        XCTAssertThrowsError(try convertPlugins("<ul><li>item</li></ul>", options: opts))
    }

    // MARK: - Strikethrough

    func testStrikethrough() throws {
        let result = try convert("<strike>Strikethrough</strike>", plugins: [
            BasePlugin(), CommonmarkPlugin(), StrikethroughPlugin()
        ])
        XCTAssertTrue(result.contains("~~Strikethrough~~"))
    }

    func testDelTag() throws {
        let result = try convert("<del>Deleted</del>", plugins: [
            BasePlugin(), CommonmarkPlugin(), StrikethroughPlugin()
        ])
        XCTAssertTrue(result.contains("~~Deleted~~"))
    }

    // MARK: - Table

    func testSimpleTable() throws {
        let html = """
        <table>
            <thead><tr><th>H1</th><th>H2</th></tr></thead>
            <tbody><tr><td>C1</td><td>C2</td></tr></tbody>
        </table>
        """
        let result = try convert(html, plugins: [BasePlugin(), CommonmarkPlugin(), TablePlugin()])
        XCTAssertTrue(result.contains("|"))
        XCTAssertTrue(result.contains("H1"))
    }

    // MARK: - Data Conversion

    func testConvertData() throws {
        let html = "<strong>Bold</strong>"
        let data = html.data(using: .utf8)!
        let result = try HTMLToMarkdown.convert(data: data)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertEqual(result, "**Bold**")
    }

    // MARK: - Empty Inline Elements

    func testEmptyBold() throws {
        XCTAssertEqual(try convert("<strong></strong>"), "")
    }

    func testEmptyBoldInParagraph() throws {
        // Empty bold in paragraph context: surrounding spaces collapse to one
        XCTAssertEqual(try convert("<p>some <strong></strong> text</p>"), "some text")
    }

    func testEmptyBoldWhitespace() throws {
        // Bold with only whitespace content: behaves same as empty, surrounding spaces collapse
        XCTAssertEqual(try convert("<p>some <strong> </strong> text</p>"), "some text")
    }

    func testEmptyItalic() throws {
        XCTAssertEqual(try convert("<em></em>"), "")
    }

    func testEmptyItalicInParagraph() throws {
        // Empty italic in paragraph context: surrounding spaces collapse to one
        XCTAssertEqual(try convert("<p>some <em></em> text</p>"), "some text")
    }

    // MARK: - Edge Cases

    func testEmptyHTML() throws {
        let result = try convert("")
        XCTAssertEqual(result, "")
    }

    func testMixedContent() throws {
        let html = "<h1>Title</h1><p>This is <strong>bold</strong> and <em>italic</em>.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("# Title"))
        XCTAssertTrue(result.contains("**bold**"))
        XCTAssertTrue(result.contains("*italic*"))
    }

    // MARK: - URL Normalization

    func testLinkWithNewlineInHref() throws {
        // Newlines in href should be stripped
        let result = try convert("<a href=\"/page\n\">broken link</a>")
        XCTAssertEqual(result, "[broken link](/page)")
    }

    func testLinkWithSpaceInHref() throws {
        let result = try convert("<a href=\"http://Open Demo\">with space inside</a>")
        XCTAssertEqual(result, "[with space inside](http://Open%20Demo)")
    }

    func testLinkWithWhitespaceAroundHref() throws {
        let result = try convert("<a href=\"  example.com  \">with whitespace around</a>")
        XCTAssertEqual(result, "[with whitespace around](example.com)")
    }

    func testLinkTitleWithDoubleQuotes() throws {
        // Title containing double quotes should use single-quote wrapping
        // &quot; decodes to " in HTML
        let result = try convert(#"<a href="/" title="&quot;link title&quot;">content</a>"#)
        XCTAssertEqual(result, #"[content](/ '"link title"')"#)
    }

    func testLinkTitleMultiline() throws {
        // Multiline title: newlines collapsed to space
        let result = try convert("<a href=\"/\" title=\"link\ntitle\">content</a>")
        XCTAssertEqual(result, "[content](/ \"link title\")")
    }

    // MARK: - Consecutive Lists Separator

    func testConsecutiveListsWithStarMarkerGetsEndComment() throws {
        var opts = CommonmarkOptions()
        opts.bulletListMarker = "*"
        let html = "<ul><li>list a</li></ul><ul><li>list b</li></ul>"
        let result = try convertPlugins(html, options: opts)
        XCTAssertEqual(result, "* list a\n\n<!--THE END-->\n\n* list b")
    }

    func testConsecutiveListsWithDashMarkerGetsEndComment() throws {
        // Go adds <!--THE END--> between consecutive lists for all bullet markers
        let html = "<ul><li>list a</li></ul><ul><li>list b</li></ul>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("<!--THE END-->"))
    }

    // MARK: - Smart Escaping

    func testEscapeListDashInParagraph() throws {
        XCTAssertEqual(try convert("<p>- not a list</p>"), "\\- not a list")
    }

    func testEscapeOrderedListInParagraph() throws {
        XCTAssertEqual(try convert("<p>1. not a list</p>"), "1\\. not a list")
    }

    func testEscapeStarListInParagraph() throws {
        XCTAssertEqual(try convert("<p>* not a list</p>"), "\\* not a list")
    }

    func testEscapePlusListInParagraph() throws {
        XCTAssertEqual(try convert("<p>+ not a list</p>"), "\\+ not a list")
    }

    func testEscapeAtxHashInParagraph() throws {
        XCTAssertEqual(try convert("<p># not title</p>"), "\\# not title")
    }

    func testNoEscapeAsteriskFollowedBySpace() throws {
        // * followed by space is NOT an emphasis marker, no escaping
        let result = try convert("<p>text * more</p>")
        XCTAssertEqual(result, "text * more")
    }

    func testEscapeAsteriskEmphasis() throws {
        // *word* would be emphasis — escape the *
        let result = try convert("<p>text *emphasis* more</p>")
        XCTAssertEqual(result, "text \\*emphasis\\* more")
    }

    // MARK: - Whitespace Collapsing

    func testWhitespaceCollapseMultipleSpaces() throws {
        // Multiple spaces between words collapse to one
        let result = try convert("<p>word1  word2   word3</p>")
        XCTAssertEqual(result, "word1 word2 word3")
    }

    func testWhitespaceCollapseNewlinesBetweenInline() throws {
        // Newlines in inline content collapse to space
        let result = try convert("<p>word1\nword2</p>")
        XCTAssertEqual(result, "word1 word2")
    }

    func testWhitespaceCollapseAroundInlineElements() throws {
        // Spaces around inline elements are preserved (one space each side)
        let result = try convert("<p>some  <b>  bold  </b>  text</p>")
        XCTAssertEqual(result, "some **bold** text")
    }

    func testWhitespaceCollapseNoSpaceBetweenInline() throws {
        // No space between adjacent inline elements = no space in output
        let result = try convert("<p>some<b>bold</b>text</p>")
        XCTAssertEqual(result, "some**bold**text")
    }

    func testWhitespaceCollapseAroundBlock() throws {
        // Whitespace-only text nodes adjacent to block elements are removed
        let result = try convert("<div>  <p>text</p>  </div>")
        XCTAssertEqual(result, "text")
    }

    // MARK: - Performance

    func testLargeHTML() throws {
        var html = ""
        for i in 1...100 {
            html += "<p>Paragraph \(i)</p>"
        }
        let startTime = Date()
        let result = try convert(html)
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertTrue(duration < 5.0, "Conversion took too long: \(duration)s")
        XCTAssertTrue(result.contains("Paragraph 1"))
        XCTAssertTrue(result.contains("Paragraph 100"))
    }

    // MARK: - Go Compatibility Tests

    func testImageAltWithBrackets() throws {
        // Go: ![\[not a link\]](/img.png) - brackets in alt should be escaped
        let result = try convert(#"<img src="/img.png" alt="[not a link]">"#)
        XCTAssertEqual(result, #"![\[not a link\]](/img.png)"#)
    }

    func testGtInTextRendersAsEntity() throws {
        // Go: Not a &gt; blockquote - > in normal text renders as &gt;
        let result = try convert("<p>Not a > blockquote</p>")
        XCTAssertEqual(result, "Not a &gt; blockquote")
    }

    func testCodeInlineSpacesOnly() throws {
        // Go: ` ` (backtick-space-backtick) - spaces-only inline code is preserved
        let result = try convert("<code> </code>")
        XCTAssertEqual(result, "` `")
    }

    func testCodeInlineEmptyIsEmpty() throws {
        // Go: (empty string) - empty inline code produces nothing
        let result = try convert("<code></code>")
        XCTAssertEqual(result, "")
    }

    func testAdjacentBoldMerges() throws {
        // Go: **bold onebold two** - adjacent bold elements without space between
        let result = try convert("<strong>bold one</strong><strong>bold two</strong>")
        XCTAssertEqual(result, "**bold onebold two**")
    }

    func testNestedBoldItalicProducesCombined() throws {
        // Go: ***hello***
        let result = try convert("<p><b><b><i><b>hello</b></i></b></b></p>")
        XCTAssertEqual(result, "***hello***")
    }

    // MARK: - URL Encoding (Go Compatibility)

    func testURLNewlineInMiddleEncoded() throws {
        // Go encodes \n as %0A (not strips) when in the middle of a URL
        let result = try convert("<a href=\"/page\n\n.html\">broken link</a>")
        XCTAssertEqual(result, "[broken link](/page%0A%0A.html)")
    }

    func testURLTabEncoded() throws {
        // Go encodes \t as %09
        let result = try convert("<a href=\"/path\there\">link</a>")
        XCTAssertEqual(result, "[link](/path%09here)")
    }

    func testURLBracketsEncoded() throws {
        // Go encodes [ and ] in URLs as %5B and %5D
        let result = try convert("<a href=\"/url[with]brackets\">link</a>")
        XCTAssertEqual(result, "[link](/url%5Bwith%5Dbrackets)")
    }

    func testURLHashPassthrough() throws {
        // Go returns "#" as-is (special case to avoid fragment confusion)
        let result = try convert("<a href=\"#\">fragment</a>")
        XCTAssertEqual(result, "[fragment](#)")
    }

    // MARK: - Link Title (Go Compatibility)

    func testLinkTitleSpacesPreserved() throws {
        // Go does NOT trim surrounding whitespace from link title
        let result = try convert("<a href=\"/\" title=\"  link title  \">content</a>")
        XCTAssertEqual(result, "[content](/ \"  link title  \")")
    }

    func testImageTitleSpacesPreserved() throws {
        // Go does NOT trim surrounding whitespace from image title
        let result = try convert("<img src=\"/img.png\" alt=\"alt\" title=\"  img title  \">")
        XCTAssertEqual(result, "![alt](/img.png \"  img title  \")")
    }

    func testLinkTitleBothQuoteTypes() throws {
        // When title contains both " and ', escape " and wrap in double quotes
        let result = try convert(#"<a href="/" title="say &quot;hello&apos; world&quot;">text</a>"#)
        XCTAssertEqual(result, #"[text](/ "say \"hello' world\"")"#)
    }

    // MARK: - Inline Code Raw Text (Go Compatibility)

    func testInlineCodeAngleBrackets() throws {
        // Go: `<b>not bold</b>` - angle brackets in code preserved as-is, not HTML-escaped
        let result = try convert("<code>&lt;b&gt;not bold&lt;/b&gt;</code>")
        XCTAssertEqual(result, "`<b>not bold</b>`")
    }

    func testInlineCodeCollapseWhitespace() throws {
        // Go collapses whitespace in inline code content
        let result = try convert("<code>foo   bar</code>")
        XCTAssertEqual(result, "`foo bar`")
    }

    func testInlineCodeCollapseNewline() throws {
        // Go collapses newlines to spaces in inline code
        let result = try convert("<code>foo\nbar</code>")
        XCTAssertEqual(result, "`foo bar`")
    }

    // MARK: - Consecutive Lists (Go Compatibility)

    func testConsecutiveOlGetsEndComment() throws {
        // Go: ol followed by another list also gets <!--THE END-->
        let html = "<ol><li>a</li></ol><ol><li>b</li></ol>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("<!--THE END-->"))
    }

    func testDisableListEndComment() throws {
        var opts = CommonmarkOptions()
        opts.disableListEndComment = true
        let html = "<ul><li>list a</li></ul><ul><li>list b</li></ul>"
        let result = try convertPlugins(html, options: opts)
        XCTAssertFalse(result.contains("<!--THE END-->"))
        let normalized = result.replacingOccurrences(of: "\n\n\n\n", with: "\n\n")
        XCTAssertEqual(normalized, "- list a\n\n- list b")
    }

    func testDisableListEndCommentVerifyNoComment() throws {
        var opts = CommonmarkOptions()
        opts.disableListEndComment = true
        let html = "<ul><li>list a</li></ul><ul><li>list b</li></ul>"
        let result = try convertPlugins(html, options: opts)
        XCTAssertFalse(result.contains("<!--THE END-->"))
        XCTAssertTrue(result.contains("- list a"))
        XCTAssertTrue(result.contains("- list b"))
    }

    // MARK: - Bracket Escaping

    func testOpenBracketWithCloseEscaped() throws {
        XCTAssertEqual(try convert("<p>[a]</p>"), "\\[a]")
    }

    func testOpenBracketWithoutCloseNotEscaped() throws {
        XCTAssertEqual(try convert("<p>[a</p>"), "[a")
    }

    func testBracketsInParagraph() throws {
        XCTAssertEqual(try convert("<p>a(b)[c]</p>"), "a(b)\\[c]")
    }

    // MARK: - Setext Heading Escape (=)

    func testSetextEqualSignEscaped() throws {
        XCTAssertEqual(try convert("<p>not title<br/>===</p>"), "not title  \n\\===")
    }

    func testSetextSingleEqualEscaped() throws {
        XCTAssertEqual(try convert("<p>not title<br/>=</p>"), "not title  \n\\=")
    }

    // MARK: - SwapTags: Bold/Italic wrapping Link

    func testBoldWrappingLink() throws {
        XCTAssertEqual(try convert("<p>before<b><a href=\"/\">middle</a></b>after</p>"), "before[**middle**](/)after")
    }

    func testItalicWrappingLink() throws {
        XCTAssertEqual(try convert("<p><em><a href=\"/page\">text</a></em></p>"), "[*text*](/page)")
    }

    func testStrongWrappingLink() throws {
        XCTAssertEqual(try convert("<strong><a href=\"/\">bold link</a></strong>"), "[**bold link**](/)")
    }

    func testBracketsInLinkText() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\">a(b)[c]</a>"), "[a(b)\\[c\\]](/page.html)")
    }

    // MARK: - SwapTags: Link wrapping Heading

    func testLinkWrappingH1() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\"><h1>Heading 1</h1></a>"), "# [Heading 1](/page.html)")
    }

    func testLinkWrappingH2() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\"><h2>Heading 2</h2></a>"), "## [Heading 2](/page.html)")
    }

    // MARK: - Adjacent Merge with Span

    func testAdjacentBoldMergesThroughSpan() throws {
        XCTAssertEqual(try convert("<p><strong>a</strong><span><strong>b</strong></span></p>"), "**ab**")
    }

    func testAdjacentBoldSpaceInSpanStopsMerge() throws {
        XCTAssertEqual(try convert("<p><strong>a</strong><span> <strong>b</strong></span></p>"), "**a** **b**")
    }

    // MARK: - List Multi-Paragraph Indentation

    func testListMultiParagraphBlankLineIndent() throws {
        let result = try convert("<ul><li><p>text1</p><p>text2</p></li></ul>")
        XCTAssertEqual(result, "- text1\n  \n  text2")
    }

    func testListBlockquoteItemIndent() throws {
        let html = "<ul><li><p>Someone once said:</p><blockquote>My famous quote</blockquote><span>- someone</span></li></ul>"
        let result = try convert(html)
        XCTAssertEqual(result, "- Someone once said:\n  \n  > My famous quote\n  \n  \\- someone")
    }
}
