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

class EscapeImageTests: XCTestCase {

    func testOpenBracketWithCloseEscaped() throws {
        XCTAssertEqual(try convert("<p>[a]</p>"), "\\[a]")
    }

    func testOpenBracketWithoutCloseNotEscaped() throws {
        XCTAssertEqual(try convert("<p>[a</p>"), "[a")
    }

    func testBracketsInParagraph() throws {
        XCTAssertEqual(try convert("<p>a(b)[c]</p>"), "a(b)\\[c]")
    }
}
