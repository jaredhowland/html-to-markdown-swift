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

class EscapeListTests: XCTestCase {

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

    func testEscapeOrderedListParenInParagraph() throws {
        // "1) item" at start of line would form an ordered list — escape the ")"
        XCTAssertEqual(try convert("<p>1) ordered list</p>"), "1\\) ordered list")
    }
}
