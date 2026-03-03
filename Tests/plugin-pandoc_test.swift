import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(PandocPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class PandocPluginTests: XCTestCase {

    // MARK: - Definition Lists

    func testDefinitionListPandocFormat() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected term in: \(result)")
        XCTAssertTrue(result.contains(":   A fruit"), "Expected Pandoc definition format in: \(result)")
    }

    func testDefinitionListNotBold() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("**Apple**"), "Term must NOT be bold in: \(result)")
    }

    // MARK: - Footnotes (Pandoc format)

    func testPandocFootnoteRef() throws {
        let html = """
        <p>Text<a href="#fn1" class="footnote-ref"><sup>1</sup></a></p>
        <section class="footnotes"><ol><li id="fn1"><p>Footnote text.<a href="#fnref1" class="footnote-back">↩︎</a></p></li></ol></section>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("[^1]"), "Expected footnote ref in: \(result)")
        XCTAssertTrue(result.contains("[^1]: Footnote text."), "Expected footnote def in: \(result)")
    }

    func testPandocFootnoteContainerRemoved() throws {
        let html = """
        <p>Text<a href="#fn1" class="footnote-ref"><sup>1</sup></a></p>
        <section class="footnotes"><ol><li id="fn1"><p>Note.<a href="#fnref1" class="footnote-back">↩︎</a></p></li></ol></section>
        """
        let result = try convert(html)
        XCTAssertFalse(result.lowercased().contains("<section"), "Should not contain raw HTML section in: \(result)")
    }

    // MARK: - Sub/Sup

    func testSubscript() throws {
        let html = "<p>H<sub>2</sub>O</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("H~2~O"), "Expected subscript in: \(result)")
    }

    func testSuperscript() throws {
        let html = "<p>E=mc<sup>2</sup></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("E=mc^2^"), "Expected superscript in: \(result)")
    }

    // MARK: - Header IDs

    func testHeadingWithId() throws {
        let html = "<h2 id=\"methods\">Methods</h2>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("## Methods {#methods}"), "Expected heading with ID in: \(result)")
    }

    func testHeadingWithoutIdUnaffected() throws {
        let html = "<h2>No ID</h2>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("{#"), "Should not add ID syntax without id attr in: \(result)")
    }

    // MARK: - Math

    func testInlineMath() throws {
        let html = "<p>The formula is <span class=\"math inline\">\\(x^2 + y^2\\)</span>.</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("$x^2 + y^2$"), "Expected inline math in: \(result)")
    }

    func testDisplayMathSpan() throws {
        let html = "<p><span class=\"math display\">\\[E = mc^2\\]</span></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("$$"), "Expected display math delimiters in: \(result)")
        XCTAssertTrue(result.contains("E = mc^2"), "Expected math content in: \(result)")
    }

    func testDisplayMathDiv() throws {
        let html = "<div class=\"math display\">\\[\\sum_{i=1}^{n} i\\]</div>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("$$"), "Expected display math delimiters in: \(result)")
    }

    func testNonMathSpanUnaffected() throws {
        let html = "<p><span class=\"highlight\">text</span></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("text"), "Expected span text in: \(result)")
        XCTAssertFalse(result.contains("$"), "Should not add math delimiters in: \(result)")
    }
}
