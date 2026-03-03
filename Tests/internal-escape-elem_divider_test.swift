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

class EscapeDividerTests: XCTestCase {

    func testEscapeStandaloneDividerDash() throws {
        // "---" alone would render as a thematic break — escape first -
        XCTAssertEqual(try convert("<p>---</p>"), "\\---")
    }

    func testEscapeDividerUnderscoreWithSpaces() throws {
        // "_ _ _" would render as a thematic break — escape first _
        XCTAssertEqual(try convert("<p>_ _ _</p>"), "\\_ _ _")
    }
}
