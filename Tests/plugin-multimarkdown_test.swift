import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(MultiMarkdownPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class MultiMarkdownPluginTests: XCTestCase {

    // MARK: - Sub / Sup

    func testSubscript() throws {
        let html = "<p>H<sub>2</sub>O</p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("H~2~O"), "Expected subscript syntax in: \(result)")
    }

    func testSuperscript() throws {
        let html = "<p>E=mc<sup>2</sup></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("E=mc^2^"), "Expected superscript syntax in: \(result)")
    }

    // MARK: - Definition Lists

    func testDefinitionListMMDFormat() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("Apple"), "Expected term in: \(result)")
        XCTAssertTrue(result.contains(":   A fruit"), "Expected MMD definition format in: \(result)")
    }

    func testDefinitionListNotBold() throws {
        let html = "<dl><dt>Apple</dt><dd>A fruit</dd></dl>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("**Apple**"), "Term must NOT be bold in MMD format: \(result)")
    }

    // MARK: - Image Attributes

    func testImageWithAttributes() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" width=\"100\" height=\"200\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{width=100px height=200px}"), "Expected px sizing in: \(result)")
    }

    func testImageWithWidthOnly() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" width=\"640\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{width=640px}"), "Expected width-only sizing in: \(result)")
        XCTAssertFalse(result.contains("height"), "Should not contain height in: \(result)")
    }

    func testImageWithHeightOnly() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" height=\"480\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{height=480px}"), "Expected height-only sizing in: \(result)")
        XCTAssertFalse(result.contains("width"), "Should not contain width in: \(result)")
    }

    func testImageWithoutAttributes() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\">"
        let result = try convert(html)
        XCTAssertFalse(result.contains("{"), "Should not have sizing braces in: \(result)")
        XCTAssertFalse(result.contains("}"), "Should not have sizing braces in: \(result)")
    }

    // MARK: - Figure / Figcaption

    func testFigcaptionSuppressed() throws {
        let html = "<figure><img src=\"img.jpg\" alt=\"Photo\"><figcaption>A beautiful photo</figcaption></figure>"
        let result = try convert(html)
        XCTAssertFalse(result.contains("A beautiful photo"), "Figcaption text must be suppressed in: \(result)")
    }

    // MARK: - Footnotes

    func testFootnoteInline() throws {
        let html = "<p>Some text<a href=\"#fn:1\" id=\"fnref:1\" title=\"see footnote\" class=\"footnote\">[1]</a></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[^1]"), "Expected footnote reference in: \(result)")
    }

    func testFootnoteDefinition() throws {
        let html = """
        <p>See footnote<a href="#fn:1" id="fnref:1" title="see footnote" class="footnote">[1]</a></p>
        <div class="footnotes">
        <hr />
        <ol>
        <li id="fn:1">Footnote text.<a href="#fnref:1" title="return to article" class="reversefootnote"> ↩</a></li>
        </ol>
        </div>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("[^1]"), "Expected inline footnote ref in: \(result)")
        XCTAssertTrue(result.contains("[^1]:"), "Expected footnote definition in: \(result)")
    }

    // MARK: - Bundled plugins

    func testStrikethroughBundled() throws {
        let html = "<p><del>text</del></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("~~text~~"), "Expected strikethrough in: \(result)")
    }

    func testTableBundled() throws {
        let html = """
        <table>
          <thead><tr><th>Name</th><th>Value</th></tr></thead>
          <tbody><tr><td>Beta</td><td>2</td></tr></tbody>
        </table>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("| Name"), "Expected table header in: \(result)")
        XCTAssertTrue(result.contains("| Beta"), "Expected table row in: \(result)")
    }
}
