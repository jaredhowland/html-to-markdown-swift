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

class CollapseTests: XCTestCase {

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
}
