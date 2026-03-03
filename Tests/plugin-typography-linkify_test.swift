import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(LinkifyPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class LinkifyPluginTests: XCTestCase {

    func testBareHttpsUrl() throws {
        let result = try convert("<p>Visit https://example.com for info.</p>")
        XCTAssertTrue(result.contains("[https://example.com](https://example.com)"),
                      "Expected linkified URL in: \(result)")
    }

    func testBareHttpUrlWithPath() throws {
        let result = try convert("<p>See https://example.com/about/us today.</p>")
        XCTAssertTrue(result.contains("[https://example.com/about/us](https://example.com/about/us)"),
                      "Expected linkified URL with path in: \(result)")
    }

    func testBareHttpUrl() throws {
        let result = try convert("<p>Visit http://example.com.</p>")
        XCTAssertTrue(result.contains("[http://example.com](http://example.com)"),
                      "Expected linkified http URL in: \(result)")
    }

    func testAlreadyLinkedUrlNotDoubleWrapped() throws {
        let result = try convert("<p><a href=\"https://example.com\">Visit here</a></p>")
        XCTAssertFalse(result.contains("[["), "Should not double-link: \(result)")
        XCTAssertTrue(result.contains("[Visit here](https://example.com)"),
                      "Original link should be preserved: \(result)")
    }

    func testTrailingPeriodStripped() throws {
        let result = try convert("<p>See https://example.com.</p>")
        XCTAssertTrue(result.contains("(https://example.com)"),
                      "Trailing period should be stripped from URL in: \(result)")
        XCTAssertTrue(result.contains(")."),
                      "Period should remain after the link in: \(result)")
    }

    func testTrailingCommaStripped() throws {
        let result = try convert("<p>See https://example.com, for info.</p>")
        XCTAssertTrue(result.contains("(https://example.com)"),
                      "Trailing comma should be stripped in: \(result)")
    }

    func testCodeBlockUrlUntouched() throws {
        let result = try convert("<pre><code>curl https://example.com</code></pre>")
        XCTAssertFalse(result.contains("](https://"),
                       "URL in code block must not be linkified in: \(result)")
        XCTAssertTrue(result.contains("https://example.com"), "URL text must still appear: \(result)")
    }

    func testInlineCodeUrlUntouched() throws {
        let result = try convert("<p>Use <code>https://example.com</code> as endpoint.</p>")
        XCTAssertFalse(result.contains("](https://"),
                       "URL in inline code must not be linkified in: \(result)")
    }

    func testUrlWithParentheses() throws {
        let result = try convert("<p>See https://en.wikipedia.org/wiki/Apple_(disambiguation) here.</p>")
        // Underscores in URLs get escaped by the Markdown renderer, so expect \_
        XCTAssertTrue(result.contains("Apple\\_(disambiguation)](https://en.wikipedia.org/wiki/Apple"),
                      "Wikipedia URL with parens should be fully linkified: \(result)")
    }

    func testUrlInParensLinkified() throws {
        let result = try convert("<p>The endpoint (https://api.example.com) is available.</p>")
        // (URL) is NOT a Markdown link — should be linkified
        XCTAssertTrue(result.contains("[https://api.example.com](https://api.example.com)"),
                      "URL in parentheses (not a Markdown link) should be linkified: \(result)")
    }

    func testExistingMarkdownLinkNotDoubleWrapped() throws {
        let html = "<p><a href=\"https://example.com\">Click here</a></p>"
        let result = try convert(html)
        let openBracketCount = result.filter { $0 == "[" }.count
        XCTAssertEqual(openBracketCount, 1, "Should have exactly one link, got: \(result)")
    }
}
