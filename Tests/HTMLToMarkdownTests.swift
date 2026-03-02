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
}
