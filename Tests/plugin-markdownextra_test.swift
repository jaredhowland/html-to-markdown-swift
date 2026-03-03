import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(MarkdownExtraPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class MarkdownExtraPluginTests: XCTestCase {

    // MARK: - Definition Lists

    func testDefinitionListMEFormat() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected term in: \(result)")
        XCTAssertTrue(result.contains(":   A fruit"), "Expected ME definition format in: \(result)")
    }

    func testDefinitionListNotBold() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("**Apple**"), "Term must NOT be bold in ME format: \(result)")
    }

    func testMultipleDefinitions() throws {
        let html = "<dl><dt>Apple</dt><dd>Fruit</dd><dt>Orange</dt><dd>Citrus fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected Apple in: \(result)")
        XCTAssertTrue(result.contains("Orange"), "Expected Orange in: \(result)")
        XCTAssertTrue(result.contains(":   Fruit"), "Expected Fruit definition in: \(result)")
        XCTAssertTrue(result.contains(":   Citrus fruit"), "Expected Orange definition in: \(result)")
    }

    // MARK: - Footnotes

    func testFootnoteInlineRef() throws {
        let html = """
        <p>Text with footnote.<sup id="fnref:1"><a href="#fn:1" class="footnote">1</a></sup></p>
        <div class="footnotes"><ol><li id="fn:1">The footnote text.</li></ol></div>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("[^1]"), "Expected footnote ref in: \(result)")
        XCTAssertTrue(result.contains("[^1]: The footnote text."), "Expected footnote def in: \(result)")
    }

    func testFootnoteDefRemovedFromBody() throws {
        let html = """
        <p>Text.<sup><a href="#fn:note" class="footnote">1</a></sup></p>
        <div class="footnotes"><ol><li id="fn:note">Note text.</li></ol></div>
        """
        let result = try convert(html)
        XCTAssertFalse(result.contains("<div"), "Should not contain raw HTML div in: \(result)")
        XCTAssertTrue(result.contains("[^note]: Note text."), "Expected footnote def in: \(result)")
    }

    // MARK: - Header IDs

    func testHeadingWithId() throws {
        let html = "<h2 id=\"section-one\">Section One</h2>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("## Section One {#section-one}"), "Expected heading with ID in: \(result)")
    }

    func testHeadingWithoutId() throws {
        let html = "<h2>No ID here</h2>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("{#"), "Should not add ID syntax when no id attr in: \(result)")
    }

    func testH1WithId() throws {
        let html = "<h1 id=\"top\">Top</h1>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("# Top {#top}"), "Expected h1 with ID in: \(result)")
    }

    // MARK: - Abbreviations

    func testAbbreviationAppendedAtEnd() throws {
        let html = "<p>Use <abbr title=\"HyperText Markup Language\">HTML</abbr> wisely.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("HTML"), "Expected abbr text inline in: \(result)")
        XCTAssertTrue(result.contains("*[HTML]: HyperText Markup Language"), "Expected abbreviation def in: \(result)")
    }

    func testAbbreviationInlineTextPreserved() throws {
        let html = "<p>Use <abbr title=\"HyperText Markup Language\">HTML</abbr> wisely.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Use HTML wisely"), "Expected inline text preserved in: \(result)")
    }

    func testAbbreviationWithoutTitleSkipped() throws {
        let html = "<p><abbr>HTML</abbr></p>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("*["), "Should not add def without title in: \(result)")
    }

    func testDuplicateAbbreviationDeduped() throws {
        let html = "<p><abbr title=\"HyperText Markup Language\">HTML</abbr> and <abbr title=\"HyperText Markup Language\">HTML</abbr></p>"
        let result = try convert(html)
        let count = result.components(separatedBy: "*[HTML]:").count - 1
        XCTAssertEqual(count, 1, "Should only have one abbreviation def, got: \(result)")
    }
}
