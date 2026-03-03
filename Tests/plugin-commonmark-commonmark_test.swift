import XCTest
@testable import HTMLToMarkdown

// helper — trimming wrapper
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

class CommonmarkTests: XCTestCase {

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

    func testLinkWrappingH1() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\"><h1>Heading 1</h1></a>"), "# [Heading 1](/page.html)")
    }

    func testLinkWrappingH2() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\"><h2>Heading 2</h2></a>"), "## [Heading 2](/page.html)")
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

    func testLinkTitleSpacesPreserved() throws {
        // Go does NOT trim surrounding whitespace from link title
        let result = try convert("<a href=\"/\" title=\"  link title  \">content</a>")
        XCTAssertEqual(result, "[content](/ \"  link title  \")")
    }

    func testLinkTitleBothQuoteTypes() throws {
        // When title contains both " and ', escape " and wrap in double quotes
        let result = try convert(#"<a href="/" title="say &quot;hello&apos; world&quot;">text</a>"#)
        XCTAssertEqual(result, #"[text](/ "say \"hello' world\"")"#)
    }

    func testBracketsInLinkText() throws {
        XCTAssertEqual(try convert("<a href=\"/page.html\">a(b)[c]</a>"), "[a(b)\\[c\\]](/page.html)")
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

    func testImageAltWithBrackets() throws {
        // Go: ![\[not a link\]](/img.png) - brackets in alt should be escaped
        let result = try convert(#"<img src="/img.png" alt="[not a link]">"#)
        XCTAssertEqual(result, #"![\[not a link\]](/img.png)"#)
    }

    func testImageTitleSpacesPreserved() throws {
        // Go does NOT trim surrounding whitespace from image title
        let result = try convert("<img src=\"/img.png\" alt=\"alt\" title=\"  img title  \">")
        XCTAssertEqual(result, "![alt](/img.png \"  img title  \")")
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

    // MARK: - Blockquote

    func testBlockquote() throws {
        XCTAssertEqual(try convert("<blockquote>Quote text</blockquote>"), "> Quote text")
    }

    func testEmptyBlockquoteProducesNothing() throws {
        // Go returns empty string for empty blockquotes
        XCTAssertEqual(try convert("<blockquote></blockquote>"), "")
        XCTAssertEqual(try convert("<blockquote>   </blockquote>"), "")
    }

    func testBlockquoteWithMultipleBreaks() throws {
        // Three <br/> elements produce only one blank line in blockquote (not three)
        let result = try convert("<blockquote>Start<br/><br/><br/>End</blockquote>")
        XCTAssertEqual(result, "> Start\n> \n> End")
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

    func testListMultiParagraphBlankLineIndent() throws {
        let result = try convert("<ul><li><p>text1</p><p>text2</p></li></ul>")
        XCTAssertEqual(result, "- text1\n  \n  text2")
    }

    func testListBlockquoteItemIndent() throws {
        let html = "<ul><li><p>Someone once said:</p><blockquote>My famous quote</blockquote><span>- someone</span></li></ul>"
        let result = try convert(html)
        XCTAssertEqual(result, "- Someone once said:\n  \n  > My famous quote\n  \n  \\- someone")
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

    // MARK: - Line Break

    func testLineBreak() throws {
        let result = try convert("Line 1<br>Line 2")
        XCTAssertTrue(result.contains("Line 1"))
        XCTAssertTrue(result.contains("Line 2"))
    }

    func testGtInTextRendersAsEntity() throws {
        // Go: Not a &gt; blockquote - > in normal text renders as &gt;
        let result = try convert("<p>Not a > blockquote</p>")
        XCTAssertEqual(result, "Not a &gt; blockquote")
    }
}
