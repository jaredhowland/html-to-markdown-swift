import XCTest
@testable import HTMLToMarkdown

private func makeConverter() throws -> Converter {
    let conv = Converter()
    try conv.Register.plugin(BasePlugin())
    try conv.Register.plugin(CommonmarkPlugin())
    try conv.Register.plugin(AtlassianPlugin())
    return conv
}

private func convert(_ html: String) throws -> String {
    let conv = try makeConverter()
    return try conv.convertString(html).trimmingCharacters(in: .whitespacesAndNewlines)
}

class AtlassianPluginTests: XCTestCase {

    // MARK: - Autolinks

    func testAutolink() throws {
        let html = "<p><a href=\"https://example.com\">https://example.com</a></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("https://example.com"), "Expected URL in: \(result)")
        XCTAssertFalse(result.contains("[https://example.com](https://example.com)"), "Should not render as bracketed link: \(result)")
    }

    func testNonAutolink() throws {
        let html = "<p><a href=\"https://example.com\">Click here</a></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("[Click here](https://example.com)"), "Expected markdown link in: \(result)")
    }

    // MARK: - Image sizing

    func testImageWithWidthAndHeight() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" width=\"640\" height=\"480\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{width=640 height=480}"), "Expected sizing in: \(result)")
    }

    func testImageWithWidthOnly() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" width=\"640\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{width=640}"), "Expected width sizing in: \(result)")
        XCTAssertFalse(result.contains("height"), "Should not contain height in: \(result)")
    }

    func testImageWithHeightOnly() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\" height=\"480\">"
        let result = try convert(html)
        XCTAssertTrue(result.contains("{height=480}"), "Expected height sizing in: \(result)")
        XCTAssertFalse(result.contains("width"), "Should not contain width in: \(result)")
    }

    func testImageWithoutSize() throws {
        let html = "<img src=\"img.jpg\" alt=\"Alt\">"
        let result = try convert(html)
        XCTAssertFalse(result.contains("{"), "Should not have sizing braces in: \(result)")
        XCTAssertFalse(result.contains("}"), "Should not have sizing braces in: \(result)")
    }

    // MARK: - Bundled plugins

    func testStrikethroughBundled() throws {
        let html = "<p><del>old text</del></p>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("~~old text~~"), "Expected strikethrough in: \(result)")
    }

    func testTableBundled() throws {
        let html = """
        <table>
          <thead><tr><th>Name</th><th>Value</th></tr></thead>
          <tbody><tr><td>Alpha</td><td>1</td></tr></tbody>
        </table>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("| Name"), "Expected table header in: \(result)")
        XCTAssertTrue(result.contains("| Alpha"), "Expected table row in: \(result)")
    }

    // MARK: - Confluence code blocks

    func testConfluenceCodeBlock() throws {
        let html = """
        <ac:structured-macro ac:name="code">
          <ac:parameter ac:name="language">java</ac:parameter>
          <ac:plain-text-body>System.out.println("Hello");</ac:plain-text-body>
        </ac:structured-macro>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("java"), "Expected language hint in: \(result)")
        XCTAssertTrue(result.contains("System.out.println"), "Expected code content in: \(result)")
    }

    func testConfluenceCodeBlockNoLanguage() throws {
        let html = """
        <ac:structured-macro ac:name="code">
          <ac:plain-text-body>echo hello</ac:plain-text-body>
        </ac:structured-macro>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("echo hello"), "Expected code content in: \(result)")
        XCTAssertTrue(result.contains("```"), "Expected fenced code block in: \(result)")
    }

    // MARK: - Confluence attachments

    func testConfluenceImageAttachment() throws {
        let html = "<ac:image><ri:attachment ri:filename=\"screenshot.png\"/></ac:image>"
        let result = try convert(html)
        XCTAssertTrue(result.contains("screenshot.png"), "Expected filename in: \(result)")
    }

    func testConfluenceLinkAttachment() throws {
        let html = """
        <ac:link><ri:attachment ri:filename="doc.pdf"/>
        <ac:plain-text-link-body>Download</ac:plain-text-link-body></ac:link>
        """
        let result = try convert(html)
        XCTAssertTrue(result.contains("[Download](doc.pdf)"), "Expected attachment link in: \(result)")
    }
}
