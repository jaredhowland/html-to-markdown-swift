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

class StrikethroughTests: XCTestCase {

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

    func testStrikethroughPreservesWhitespace() throws {
        // Spaces around <del> content should be outside the ~~ delimiters
        let result = try convert("<p>before<del> text </del>after</p>", plugins: [
            BasePlugin(), CommonmarkPlugin(), StrikethroughPlugin()
        ])
        XCTAssertEqual(result, "before ~~text~~ after")
    }
}
