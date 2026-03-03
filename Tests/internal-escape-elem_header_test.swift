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

class EscapeHeaderTests: XCTestCase {

    func testEscapeAtxHashInParagraph() throws {
        XCTAssertEqual(try convert("<p># not title</p>"), "\\# not title")
    }

    func testSetextEqualSignEscaped() throws {
        XCTAssertEqual(try convert("<p>not title<br/>===</p>"), "not title  \n\\===")
    }

    func testSetextSingleEqualEscaped() throws {
        XCTAssertEqual(try convert("<p>not title<br/>=</p>"), "not title  \n\\=")
    }
}
